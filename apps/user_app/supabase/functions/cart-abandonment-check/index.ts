// Cart Abandonment Check - Scheduled Edge Function
// This function should be scheduled to run every hour via Supabase Cron
// Checks for cart items older than 6 hours and sends notifications

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Find all cart items that are 6+ hours old and haven't been notified
    // Only check items where abandonment_notified_at is NULL or was notified more than 24 hours ago (to allow re-notification)
    const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString()
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
    
    // First, get all active cart items that are 6+ hours old
    const { data: allAbandonedCarts, error: cartError } = await supabase
      .from('cart_items')
      .select(`
        id,
        user_id,
        service_id,
        created_at,
        abandonment_notified_at,
        services(name)
      `)
      .eq('status', 'active')
      .lte('created_at', sixHoursAgo)
      .order('user_id', { ascending: true })

    if (cartError) {
      throw cartError
    }

    // Filter in JavaScript to check abandonment_notified_at
    // Only include items that haven't been notified OR were notified more than 24 hours ago
    const abandonedCarts = (allAbandonedCarts || []).filter(item => {
      if (!item.abandonment_notified_at) {
        return true // Never notified
      }
      const notifiedAt = new Date(item.abandonment_notified_at)
      const twentyFourHoursAgoDate = new Date(twentyFourHoursAgo)
      return notifiedAt < twentyFourHoursAgoDate // Notified more than 24 hours ago
    })

    if (abandonedCarts.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No abandoned carts found', count: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Group by user_id to send one notification per user
    const userCarts = new Map<string, any[]>()
    for (const item of abandonedCarts) {
      if (!userCarts.has(item.user_id)) {
        userCarts.set(item.user_id, [])
      }
      userCarts.get(item.user_id)!.push(item)
    }

    const results = []
    
    // Send notification for each user
    for (const [userId, items] of userCarts.entries()) {
      const serviceNames = items
        .map(item => item.services?.name || 'item')
        .filter((name, index, arr) => arr.indexOf(name) === index) // unique names
      
      const title = 'Complete Your Order'
      const body = items.length > 1
        ? `You have ${items.length} items waiting in your cart. Complete your order now!`
        : `Your ${serviceNames[0]} is waiting in your cart. Complete your order now!`

      // Call send-push-notification function
      const { data: notificationResult, error: notificationError } = await supabase.functions.invoke(
        'send-push-notification',
        {
          body: {
            userId,
            title,
            body,
            data: {
              type: 'cart_abandonment',
              cart_count: items.length,
              service_ids: items.map(i => i.service_id),
            },
            appTypes: ['user_app'],
          },
        }
      )

      if (notificationError) {
        console.error(`Error sending notification to user ${userId}:`, notificationError)
        results.push({ userId, success: false, error: notificationError.message })
      } else {
        // Mark all items for this user as notified
        const itemIds = items.map(i => i.id)
        const { error: updateError } = await supabase
          .from('cart_items')
          .update({ abandonment_notified_at: new Date().toISOString() })
          .in('id', itemIds)
        
        if (updateError) {
          console.error(`Error updating abandonment_notified_at for user ${userId}:`, updateError)
        }
        
        results.push({ userId, success: true, itemsCount: items.length })
      }
    }

    const successCount = results.filter(r => r.success).length
    const failCount = results.filter(r => !r.success).length

    return new Response(
      JSON.stringify({
        message: `Processed ${userCarts.size} users with abandoned carts`,
        totalUsers: userCarts.size,
        totalItems: abandonedCarts.length,
        successCount,
        failCount,
        results,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error: any) {
    console.error('Error in cart-abandonment-check:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
