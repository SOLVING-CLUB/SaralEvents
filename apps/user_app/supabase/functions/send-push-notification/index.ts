import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
// Google Auth Library for proper OAuth2 authentication (Firebase Admin SDK compatible)
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9.0.0'

// FCM Service Account JSON (base64 encoded) - loaded from Supabase secrets
const FCM_SERVICE_ACCOUNT_BASE64 = Deno.env.get('FCM_SERVICE_ACCOUNT_BASE64') ?? ''

interface FCMRequest {
  userId?: string
  tokens?: string[]
  title: string
  body: string
  data?: Record<string, any>
  imageUrl?: string
  appTypes?: string[] // Filter tokens by app_type: ['user_app'], ['vendor_app'], or both
}

interface ServiceAccount {
  project_id: string
  private_key: string
  client_email: string
  type: string
}

// Initialize Google Auth with service account
let googleAuth: GoogleAuth | null = null

function getGoogleAuth(): GoogleAuth {
  if (googleAuth) {
    return googleAuth
  }

  if (!FCM_SERVICE_ACCOUNT_BASE64) {
    throw new Error('FCM service account not configured. Please set FCM_SERVICE_ACCOUNT_BASE64 secret.')
  }

  // Parse service account JSON
  const serviceAccountJson = atob(FCM_SERVICE_ACCOUNT_BASE64)
  const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson)

  // Initialize Google Auth with service account credentials
  googleAuth = new GoogleAuth({
    credentials: {
      client_email: serviceAccount.client_email,
      private_key: serviceAccount.private_key.replace(/\\n/g, '\n'),
      project_id: serviceAccount.project_id,
    },
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })

  return googleAuth
}

// Send FCM message using FCM REST API v1 with proper OAuth2 authentication
async function sendFCMessage(
  projectId: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, any>,
  imageUrl?: string
): Promise<any> {
  // Get access token using Google Auth Library (Firebase Admin SDK compatible)
  const auth = getGoogleAuth()
  const client = await auth.getClient()
  const accessToken = await client.getAccessToken()

  if (!accessToken.token) {
    throw new Error('Failed to get access token from Google Auth')
  }

  // Build message payload
  const message: any = {
    message: {
      token: token,
      notification: {
        title: title,
        body: body,
        ...(imageUrl ? { imageUrl: imageUrl } : {}),
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'default',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    },
  }

  // Add data payload if provided
  if (data) {
    message.message.data = Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)])
    )
  }

  // Send to FCM REST API v1
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
  
  const response = await fetch(fcmUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken.token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(message),
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`FCM API error: ${error}`)
  }

  return await response.json()
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
      },
    })
  }

  try {
    // Parse request body
    const body: FCMRequest = await req.json()

    // Validate required fields
    if (!body.title || !body.body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: title, body' }),
        { 
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Initialize Google Auth (validates service account)
    let projectId: string
    try {
      const auth = getGoogleAuth()
      const serviceAccountJson = atob(FCM_SERVICE_ACCOUNT_BASE64)
      const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson)
      projectId = serviceAccount.project_id
    } catch (error: any) {
      return new Response(
        JSON.stringify({ 
          error: 'Failed to initialize Firebase authentication',
          details: error.message 
        }),
        { 
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Get target tokens
    let targetTokens: string[] = body.tokens || []

    // If tokens not provided, fetch from database
    if (targetTokens.length === 0 && body.userId) {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      // Build query with app_type filtering if appTypes is provided
      let query = supabase
        .from('fcm_tokens')
        .select('token')
        .eq('user_id', body.userId)
        .eq('is_active', true)

      // Filter by app_type if appTypes is specified
      if (body.appTypes && body.appTypes.length > 0) {
        query = query.in('app_type', body.appTypes)
      }

      const { data: tokenData, error } = await query

      if (error) {
        throw new Error(`Failed to fetch tokens: ${error.message}`)
      }

      targetTokens = tokenData?.map(t => t.token) || []
      
      // Log for debugging
      console.log(`Fetched ${targetTokens.length} tokens for user ${body.userId}${body.appTypes ? ` with appTypes: ${body.appTypes.join(', ')}` : ' (no app_type filter)'}`)
    }

    if (targetTokens.length === 0) {
      return new Response(
        JSON.stringify({ 
          message: 'No active tokens found',
          success: false 
        }),
        { 
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Send notifications to all tokens using Firebase Admin SDK compatible authentication
    const results = await Promise.allSettled(
      targetTokens.map(token =>
        sendFCMessage(
          projectId,
          token,
          body.title,
          body.body,
          body.data,
          body.imageUrl
        )
      )
    )

    const successful = results.filter(r => r.status === 'fulfilled').length
    const failed = results.filter(r => r.status === 'rejected').length

    return new Response(
      JSON.stringify({
        success: true,
        sent: successful,
        failed: failed,
        total: targetTokens.length,
        results: results.map((r, i) => ({
          token: targetTokens[i]?.substring(0, 20) + '...', // Partial token for logging
          status: r.status,
          ...(r.status === 'fulfilled' ? { result: r.value } : { error: r.reason?.message }),
        })),
      }),
      { 
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )

  } catch (error: any) {
    console.error('Error sending push notification:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        details: error.message 
      }),
      { 
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  }
})
