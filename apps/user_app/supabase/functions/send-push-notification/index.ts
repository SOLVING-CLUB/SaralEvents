import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// FCM Service Account JSON (base64 encoded) - loaded from Supabase secrets
const FCM_SERVICE_ACCOUNT_BASE64 = Deno.env.get('FCM_SERVICE_ACCOUNT_BASE64') ?? ''

interface FCMRequest {
  userId?: string
  tokens?: string[]
  title: string
  body: string
  data?: Record<string, any>
  imageUrl?: string
}

interface ServiceAccount {
  project_id: string
  private_key: string
  client_email: string
}

// Get OAuth2 access token from Google
async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const jwtHeader = {
    alg: 'RS256',
    typ: 'JWT',
  }

  const now = Math.floor(Date.now() / 1000)
  const jwtClaim = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  }

  // Create JWT
  const jwt = await createJWT(jwtHeader, jwtClaim, serviceAccount.private_key)

  // Exchange JWT for access token
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
    throw new Error(`Failed to get access token: ${error}`)
  }

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

// Create JWT token
async function createJWT(header: any, claim: any, privateKey: string): Promise<string> {
  const base64UrlEncode = (str: string) => {
    return btoa(str)
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '')
  }

  const headerB64 = base64UrlEncode(JSON.stringify(header))
  const claimB64 = base64UrlEncode(JSON.stringify(claim))

  const message = `${headerB64}.${claimB64}`
  
  // Import private key
  const keyData = privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '')
  
  const keyBuffer = Uint8Array.from(atob(keyData), c => c.charCodeAt(0))
  
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBuffer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  )

  // Sign the message
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(message)
  )

  const signatureB64 = base64UrlEncode(String.fromCharCode(...new Uint8Array(signature)))
  
  return `${message}.${signatureB64}`
}

// Send FCM message using V1 API
async function sendFCMessage(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, any>,
  imageUrl?: string
): Promise<any> {
  const message: any = {
    message: {
      token: token,
      notification: {
        title: title,
        body: body,
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

  if (data) {
    message.message.data = Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)])
    )
  }

  if (imageUrl) {
    message.message.notification.imageUrl = imageUrl
  }

  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
  
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
    // Validate FCM service account is configured
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

    // Parse service account JSON
    const serviceAccountJson = atob(FCM_SERVICE_ACCOUNT_BASE64)
    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson)

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

    // Get target tokens
    let targetTokens: string[] = body.tokens || []

    // If tokens not provided, fetch from database
    if (targetTokens.length === 0 && body.userId) {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      const { data: tokenData, error } = await supabase
        .from('fcm_tokens')
        .select('token')
        .eq('user_id', body.userId)
        .eq('is_active', true)

      if (error) {
        throw new Error(`Failed to fetch tokens: ${error.message}`)
      }

      targetTokens = tokenData?.map(t => t.token) || []
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

    // Get access token
    const accessToken = await getAccessToken(serviceAccount)

    // Send notifications to all tokens
    const results = await Promise.allSettled(
      targetTokens.map(token =>
        sendFCMessage(
          accessToken,
          serviceAccount.project_id,
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
          token: targetTokens[i],
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

  } catch (error) {
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