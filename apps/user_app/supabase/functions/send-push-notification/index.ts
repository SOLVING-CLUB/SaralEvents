import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from 'https://deno.land/x/djwt@v2.8/mod.ts'
// Use global crypto - Deno has it built-in

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

// Cache for access token
let cachedAccessToken: { token: string; expiresAt: number } | null = null

// Get OAuth2 access token using JWT (Deno-compatible)
async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  // Check if cached token is still valid (with 5 minute buffer)
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 5 * 60 * 1000) {
    return cachedAccessToken.token
  }

  // Create JWT for OAuth2 assertion
  const now = getNumericDate(new Date())
  const jwtPayload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600, // 1 hour
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }

  // Prepare private key for import
  const privateKeyPem = serviceAccount.private_key.replace(/\\n/g, '\n')
  
  // Convert PEM to ArrayBuffer for Web Crypto API
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  const pemContents = privateKeyPem
    .replace(pemHeader, '')
    .replace(pemFooter, '')
    .replace(/\s/g, '')
  
  // Decode base64 to binary
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

  // Import private key
  let privateKey: CryptoKey
  try {
    privateKey = await crypto.subtle.importKey(
      'pkcs8',
      binaryDer.buffer,
      {
        name: 'RSASSA-PKCS1-v1_5',
        hash: 'SHA-256',
      },
      false,
      ['sign']
    )
    console.log('Successfully imported private key')
  } catch (error: any) {
    console.error('Error importing private key:', error.message)
    throw new Error(`Failed to import private key: ${error.message}`)
  }

  // Create JWT
  let jwt: string
  try {
    jwt = await create(
      { alg: 'RS256', typ: 'JWT' },
      jwtPayload,
      privateKey
    )
    console.log('Successfully created JWT')
  } catch (error: any) {
    console.error('Error creating JWT:', error.message)
    throw new Error(`Failed to create JWT: ${error.message}`)
  }

  // Exchange JWT for access token
  try {
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    })

    if (!tokenResponse.ok) {
      const error = await tokenResponse.text()
      console.error('OAuth2 token request failed:', error)
      throw new Error(`Failed to get access token: ${error}`)
    }

    const tokenData = await tokenResponse.json()
    
    // Cache the token
    cachedAccessToken = {
      token: tokenData.access_token,
      expiresAt: Date.now() + (tokenData.expires_in * 1000),
    }

    console.log('Successfully obtained OAuth2 access token')
    return tokenData.access_token
  } catch (error: any) {
    console.error('Error in getAccessToken:', error.message)
    throw error
  }
}

// Send FCM message using FCM REST API v1 with OAuth2 authentication
async function sendFCMessage(
  projectId: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, any>,
  imageUrl?: string
): Promise<any> {
  // Get service account
  if (!FCM_SERVICE_ACCOUNT_BASE64) {
    throw new Error('FCM service account not configured. Please set FCM_SERVICE_ACCOUNT_BASE64 secret.')
  }

  const serviceAccountJson = atob(FCM_SERVICE_ACCOUNT_BASE64)
  const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson)

  // Get access token
  const accessToken = await getAccessToken(serviceAccount)

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
  
  try {
    const response = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(message),
    })

    if (!response.ok) {
      const error = await response.text()
      console.error('FCM API error:', error)
      throw new Error(`FCM API error: ${error}`)
    }

    const result = await response.json()
    console.log('FCM message sent successfully:', result.name)
    return result
  } catch (error: any) {
    console.error('Error sending FCM message:', error.message)
    throw error
  }
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

    // Get service account for project ID
    if (!FCM_SERVICE_ACCOUNT_BASE64) {
      return new Response(
        JSON.stringify({ 
          error: 'FCM service account not configured. Please set FCM_SERVICE_ACCOUNT_BASE64 secret.'
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

    let projectId: string
    try {
      const serviceAccountJson = atob(FCM_SERVICE_ACCOUNT_BASE64)
      const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson)
      projectId = serviceAccount.project_id
    } catch (error: any) {
      return new Response(
        JSON.stringify({ 
          error: 'Failed to parse service account',
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

    // Initialize Supabase client for database operations
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get target tokens
    let targetTokens: string[] = body.tokens || []

    // If tokens not provided, fetch from database
    if (targetTokens.length === 0 && body.userId) {
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

    // Send notifications to all tokens
    console.log(`Sending notifications to ${targetTokens.length} token(s)`)
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
    console.log(`Notification sending completed: ${results.filter(r => r.status === 'fulfilled').length} successful, ${results.filter(r => r.status === 'rejected').length} failed`)

    const successful = results.filter(r => r.status === 'fulfilled').length
    const failed = results.filter(r => r.status === 'rejected').length

    // Auto-cleanup: Mark UNREGISTERED tokens as inactive
    const tokensToDeactivate: string[] = []
    results.forEach((r, i) => {
      if (r.status === 'rejected') {
        const errorMsg = r.reason?.message || ''
        console.error(`Failed to send to token ${i}:`, errorMsg)
        
        // Check if error is UNREGISTERED (token is invalid/expired)
        if (errorMsg.includes('UNREGISTERED') || errorMsg.includes('NOT_FOUND')) {
          tokensToDeactivate.push(targetTokens[i])
        }
      }
    })

    // Deactivate invalid tokens
    if (tokensToDeactivate.length > 0) {
      try {
        await supabase
          .from('fcm_tokens')
          .update({ is_active: false })
          .in('token', tokensToDeactivate)
        
        console.log(`Deactivated ${tokensToDeactivate.length} invalid token(s)`)
      } catch (error) {
        console.error('Failed to deactivate invalid tokens:', error)
      }
    }

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
