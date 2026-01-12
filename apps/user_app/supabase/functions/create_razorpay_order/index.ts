import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Razorpay configuration - loaded from Supabase secrets
const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID') ?? ''
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET') ?? ''

interface RazorpayOrderRequest {
  amount: number
  currency: string
  receipt: string
  notes?: Record<string, any>
  payment_capture?: number
}

interface RazorpayOrderResponse {
  id: string
  entity: string
  amount: number
  amount_paid: number
  amount_due: number
  currency: string
  receipt: string
  status: string
  attempts: number
  notes: Record<string, any>
  created_at: number
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
    // Validate Razorpay credentials are set
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      return new Response(
        JSON.stringify({ error: 'Razorpay credentials not configured. Please set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET secrets.' }),
        { 
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Parse request body
    const body: RazorpayOrderRequest = await req.json()
    
    // Validate required fields
    if (!body.amount || !body.currency || !body.receipt) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: amount, currency, receipt' }),
        { 
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Validate amount (must be positive)
    if (body.amount <= 0) {
      return new Response(
        JSON.stringify({ error: 'Amount must be greater than 0' }),
        { 
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    // Create Razorpay order
    const orderData = {
      amount: body.amount,
      currency: body.currency,
      receipt: body.receipt,
      notes: body.notes || {},
      payment_capture: body.payment_capture || 1, // Auto-capture by default
    }

    console.log('Creating Razorpay order:', orderData)

    // Make request to Razorpay API
    const razorpayResponse = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`)}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(orderData),
    })

    if (!razorpayResponse.ok) {
      const errorText = await razorpayResponse.text()
      console.error('Razorpay API error:', errorText)
      
      return new Response(
        JSON.stringify({ 
          error: 'Failed to create Razorpay order',
          details: errorText 
        }),
        { 
          status: razorpayResponse.status,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

    const order: RazorpayOrderResponse = await razorpayResponse.json()
    
    console.log('Razorpay order created successfully:', order.id)

    // Log the order creation in Supabase (optional)
    try {
      const supabaseClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      await supabaseClient
        .from('payment_orders')
        .insert({
          razorpay_order_id: order.id,
          amount: order.amount,
          currency: order.currency,
          receipt: order.receipt,
          status: order.status,
          notes: order.notes,
          created_at: new Date(order.created_at * 1000).toISOString(),
        })
    } catch (dbError) {
      console.warn('Failed to log order to database:', dbError)
      // Don't fail the request if database logging fails
    }

    return new Response(
      JSON.stringify(order),
      { 
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )

  } catch (error) {
    console.error('Error creating Razorpay order:', error)
    
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
