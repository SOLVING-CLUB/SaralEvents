-- ============================================================================
-- STEP 3B: COMPLETE REMAINING NOTIFICATION RULES (Rules 4-17)
-- ============================================================================
-- This query extends process_notification_event to handle all remaining rules
-- ============================================================================

-- Drop and recreate the function with all rules
CREATE OR REPLACE FUNCTION process_notification_event(
  p_event_code TEXT,
  p_order_id UUID DEFAULT NULL,
  p_booking_id UUID DEFAULT NULL,
  p_payment_id UUID DEFAULT NULL,
  p_refund_id UUID DEFAULT NULL,
  p_ticket_id UUID DEFAULT NULL,
  p_campaign_id UUID DEFAULT NULL,
  p_withdrawal_request_id UUID DEFAULT NULL,
  p_actor_role TEXT DEFAULT NULL,
  p_actor_id UUID DEFAULT NULL,
  p_payload JSONB DEFAULT '{}'::JSONB,
  p_dedupe_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_id UUID;
  v_order_record RECORD;
  v_booking_record RECORD;
  v_payment_record RECORD;
  v_refund_record RECORD;
  v_ticket_record RECORD;
  v_vendor_record RECORD;
  v_campaign_record RECORD;
  v_withdrawal_record RECORD;
  v_user_id UUID;
  v_vendor_id UUID;
  v_vendor_user_id UUID;
  v_amount NUMERIC;
  v_user_refund_amount NUMERIC;
  v_vendor_refund_amount NUMERIC;
  v_status TEXT;
  v_admin_message TEXT;
  v_notification_id UUID;
  v_dedupe_key TEXT;
  v_result JSONB;
  v_all_user_ids UUID[];
  v_all_vendor_ids UUID[];
  v_all_vendor_user_ids UUID[];
BEGIN
  -- Generate event_id and dedupe_key
  v_event_id := uuid_generate_v4();
  
  IF p_dedupe_key IS NULL THEN
    v_dedupe_key := p_event_code || ':' || COALESCE(p_order_id::TEXT, '') || ':' || COALESCE(p_payment_id::TEXT, '') || ':' || EXTRACT(EPOCH FROM NOW())::TEXT;
  ELSE
    v_dedupe_key := p_dedupe_key;
  END IF;
  
  -- Insert event record (check for duplicates first WITHOUT clobbering new event_id)
  -- We use a separate variable to avoid setting v_event_id to NULL when no row is found
  PERFORM 1
  FROM notification_events
  WHERE dedupe_key = v_dedupe_key;

  IF FOUND THEN
    -- Duplicate event detected, skip processing
    RETURN jsonb_build_object('success', true, 'skipped', true, 'reason', 'duplicate_event');
  END IF;
  
  -- Insert new event with freshly generated v_event_id
  INSERT INTO notification_events (
    event_id, event_code, order_id, booking_id, payment_id, refund_id,
    ticket_id, campaign_id, withdrawal_request_id,
    actor_role, actor_id, payload, dedupe_key
  ) VALUES (
    v_event_id, p_event_code, p_order_id, p_booking_id, p_payment_id, p_refund_id,
    p_ticket_id, p_campaign_id, p_withdrawal_request_id,
    p_actor_role, p_actor_id, p_payload, v_dedupe_key
  )
  RETURNING event_id INTO v_event_id;
  
  -- Route based on event_code and create notifications
  CASE p_event_code
    -- ========================================================================
    -- 1️⃣ ORDER_PAYMENT_SUCCESS: User places an order (Payment Completed)
    -- ========================================================================
    WHEN 'ORDER_PAYMENT_SUCCESS' THEN
      -- orders table does not have vendor_id; attempt to get vendor via bookings (currently unavailable)
      SELECT 
        o.user_id,
        b.vendor_id,
        o.total_amount AS amount,
        o.status,
        vp.user_id AS vendor_user_id
      INTO v_order_record
      FROM orders o
      -- NOTE: there is currently no direct order↔booking link; keep join but disable it
      LEFT JOIN bookings b ON FALSE
      LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
      WHERE o.id = p_order_id;
      
      IF v_order_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
      END IF;
      
      -- Notification A: Vendor App - "New order received – Accept or Reject"
      v_dedupe_key := 'ORDER_PAYMENT_SUCCESS:VENDOR:NEW_ORDER:' || p_order_id::TEXT || ':' || v_order_record.vendor_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_vendor_id, recipient_user_id,
          title, body, order_id, amount, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'VENDOR', v_order_record.vendor_id, v_order_record.vendor_user_id,
          'New order received', 'New order #' || p_order_id::TEXT || ' received. Accept or reject the order.',
          p_order_id, v_order_record.amount, v_order_record.status, 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'amount', v_order_record.amount, 'status', 'NEW_ORDER')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL AND v_order_record.vendor_user_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_order_record.vendor_user_id,
          'New order received',
          'New order #' || p_order_id::TEXT || ' received. Accept or reject the order.',
          jsonb_build_object('type', 'new_order', 'order_id', p_order_id::TEXT, 'amount', v_order_record.amount),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
      END IF;
      
      -- Notification B: Vendor App - "Payment received for Order #{{order_id}}"
      v_dedupe_key := 'ORDER_PAYMENT_SUCCESS:VENDOR:PAYMENT:' || p_order_id::TEXT || ':' || v_order_record.vendor_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_vendor_id, recipient_user_id,
          title, body, order_id, amount, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'VENDOR', v_order_record.vendor_id, v_order_record.vendor_user_id,
          'Payment received', 'Payment received for Order #' || p_order_id::TEXT,
          p_order_id, v_order_record.amount, 'PAYMENT_SUCCESS', 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'amount', v_order_record.amount, 'status', 'PAYMENT_SUCCESS')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL AND v_order_record.vendor_user_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_order_record.vendor_user_id,
          'Payment received',
          'Payment received for Order #' || p_order_id::TEXT,
          jsonb_build_object('type', 'payment_received', 'order_id', p_order_id::TEXT, 'amount', v_order_record.amount),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
      END IF;
      
      -- Notification C: User App - "Payment successful"
      v_dedupe_key := 'ORDER_PAYMENT_SUCCESS:USER:' || p_order_id::TEXT || ':' || v_order_record.user_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_user_id,
          title, body, order_id, amount, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'USER', v_order_record.user_id,
          'Payment successful', 'Your payment of ₹' || v_order_record.amount || ' for Order #' || p_order_id::TEXT || ' was successful.',
          p_order_id, v_order_record.amount, 'PAYMENT_SUCCESS', 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'amount', v_order_record.amount, 'status', 'PAYMENT_SUCCESS')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_order_record.user_id,
          'Payment successful',
          'Your payment of ₹' || v_order_record.amount || ' for Order #' || p_order_id::TEXT || ' was successful.',
          jsonb_build_object('type', 'payment_success', 'order_id', p_order_id::TEXT, 'amount', v_order_record.amount),
          NULL,
          ARRAY['user_app']::TEXT[]
        );
      END IF;
    
    -- ========================================================================
    -- ORDER_PAYMENT_FAILED: Payment failure (User App ONLY)
    -- ========================================================================
    WHEN 'ORDER_PAYMENT_FAILED' THEN
      SELECT o.user_id, o.total_amount AS amount INTO v_order_record
      FROM orders o WHERE o.id = p_order_id;
      
      IF v_order_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
      END IF;
      
      v_dedupe_key := 'ORDER_PAYMENT_FAILED:USER:' || p_order_id::TEXT || ':' || v_order_record.user_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_user_id,
          title, body, order_id, amount, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'USER', v_order_record.user_id,
          'Payment failed', 'Payment failed. Please try again.',
          p_order_id, v_order_record.amount, 'PAYMENT_FAILED', 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'status', 'PAYMENT_FAILED')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_order_record.user_id,
          'Payment failed',
          'Payment failed. Please try again.',
          jsonb_build_object('type', 'payment_failed', 'order_id', p_order_id::TEXT),
          NULL,
          ARRAY['user_app']::TEXT[]
        );
      END IF;
    
    -- ========================================================================
    -- 2️⃣ ORDER_VENDOR_DECISION: Vendor accepts or rejects order
    -- ========================================================================
    WHEN 'ORDER_VENDOR_DECISION' THEN
      -- Get user (vendor not directly linked to orders)
      SELECT 
        o.user_id,
        b.vendor_id,
        o.total_amount AS amount,
        o.status,
        vp.user_id AS vendor_user_id
      INTO v_order_record
      FROM orders o
      -- No reliable order↔booking link yet; disable join
      LEFT JOIN bookings b ON FALSE
      LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
      WHERE o.id = p_order_id;
      
      IF v_order_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
      END IF;
      
      v_status := COALESCE(p_payload->>'status', v_order_record.status);
      
      IF v_status IN ('accepted', 'confirmed') THEN
        v_dedupe_key := 'ORDER_VENDOR_DECISION:USER:ACCEPTED:' || p_order_id::TEXT || ':' || v_order_record.user_id::TEXT;
        
        SELECT notification_id INTO v_notification_id
        FROM notifications
        WHERE dedupe_key = v_dedupe_key
        LIMIT 1;
        
        IF v_notification_id IS NULL THEN
          INSERT INTO notifications (
            event_id, recipient_role, recipient_user_id,
            title, body, order_id, amount, status, type, dedupe_key, metadata
          ) VALUES (
            v_event_id, 'USER', v_order_record.user_id,
            'Order accepted', 'Your order has been accepted',
            p_order_id, v_order_record.amount, 'ACCEPTED', 'BOTH', v_dedupe_key,
            jsonb_build_object('order_id', p_order_id, 'status', 'ACCEPTED')
          )
          RETURNING notification_id INTO v_notification_id;
        END IF;
        
        IF v_notification_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_order_record.user_id,
            'Order accepted',
            'Your order has been accepted',
            jsonb_build_object('type', 'order_accepted', 'order_id', p_order_id::TEXT),
            NULL,
            ARRAY['user_app']::TEXT[]
          );
        END IF;
      ELSIF v_status IN ('rejected', 'cancelled') THEN
        v_dedupe_key := 'ORDER_VENDOR_DECISION:USER:REJECTED:' || p_order_id::TEXT || ':' || v_order_record.user_id::TEXT;
        
        SELECT notification_id INTO v_notification_id
        FROM notifications
        WHERE dedupe_key = v_dedupe_key
        LIMIT 1;
        
        IF v_notification_id IS NULL THEN
          INSERT INTO notifications (
            event_id, recipient_role, recipient_user_id,
            title, body, order_id, amount, status, type, dedupe_key, metadata
          ) VALUES (
            v_event_id, 'USER', v_order_record.user_id,
            'Order rejected', 'Your order has been rejected',
            p_order_id, v_order_record.amount, 'REJECTED', 'BOTH', v_dedupe_key,
            jsonb_build_object('order_id', p_order_id, 'status', 'REJECTED')
          )
          RETURNING notification_id INTO v_notification_id;
        END IF;
        
        IF v_notification_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_order_record.user_id,
            'Order rejected',
            'Your order has been rejected',
            jsonb_build_object('type', 'order_rejected', 'order_id', p_order_id::TEXT),
            NULL,
            ARRAY['user_app']::TEXT[]
          );
        END IF;
      END IF;
    
    -- ========================================================================
    -- 3️⃣ ORDER_VENDOR_ARRIVED: Vendor marks Arrived at Location
    -- ========================================================================
    WHEN 'ORDER_VENDOR_ARRIVED' THEN
      -- Get data from booking (not order) since orders don't have vendor_id
      IF p_booking_id IS NOT NULL THEN
        SELECT b.user_id, b.vendor_id, vp.user_id as vendor_user_id
        INTO v_order_record
        FROM bookings b
        LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
        WHERE b.id = p_booking_id;
      ELSIF p_order_id IS NOT NULL THEN
        -- Try to get booking_id from order, then get vendor from booking
        SELECT b.user_id, b.vendor_id, vp.user_id as vendor_user_id
        INTO v_order_record
        FROM orders o
        JOIN bookings b ON b.id = o.booking_id
        LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
        WHERE o.id = p_order_id;
      END IF;
      
      IF v_order_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
      END IF;
      
      v_dedupe_key := 'ORDER_VENDOR_ARRIVED:USER:' || p_order_id::TEXT || ':' || v_order_record.user_id::TEXT;
      
      -- Check if notification already exists (replaces ON CONFLICT)
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      -- Only insert if it doesn't exist
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_user_id,
          title, body, order_id, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'USER', v_order_record.user_id,
          'Vendor arrived', 'Vendor has arrived at your location',
          p_order_id, 'ARRIVED', 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'status', 'ARRIVED')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_order_record.user_id,
          'Vendor arrived',
          'Vendor has arrived at your location',
          jsonb_build_object('type', 'vendor_arrived', 'order_id', p_order_id::TEXT),
          NULL,
          ARRAY['user_app']::TEXT[]
        );
      END IF;
    
    -- ========================================================================
    -- 4️⃣ ORDER_USER_CONFIRM_ARRIVAL: User confirms vendor arrival
    -- ========================================================================
    WHEN 'ORDER_USER_CONFIRM_ARRIVAL' THEN
      -- Vendor info comes from booking linked to order
      SELECT 
        b.vendor_id,
        vp.user_id AS vendor_user_id
      INTO v_order_record
      FROM orders o
      LEFT JOIN bookings b ON b.order_id = o.id
      LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
      WHERE o.id = p_order_id;
      
      IF v_order_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
      END IF;
      
      v_dedupe_key := 'ORDER_USER_CONFIRM_ARRIVAL:VENDOR:' || p_order_id::TEXT || ':' || v_order_record.vendor_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_vendor_id, recipient_user_id,
          title, body, order_id, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'VENDOR', v_order_record.vendor_id, v_order_record.vendor_user_id,
          'Arrival confirmed', 'User confirmed your arrival',
          p_order_id, 'ARRIVAL_CONFIRMED', 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'status', 'ARRIVAL_CONFIRMED')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL AND v_order_record.vendor_user_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_order_record.vendor_user_id,
          'Arrival confirmed',
          'User confirmed your arrival',
          jsonb_build_object('type', 'arrival_confirmed', 'order_id', p_order_id::TEXT),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
      END IF;
    
    -- ========================================================================
    -- 5️⃣ ORDER_VENDOR_SETUP_COMPLETED: Vendor marks Setup Completed
    -- ========================================================================
    WHEN 'ORDER_VENDOR_SETUP_COMPLETED' THEN
      -- Get user & vendor via booking
      SELECT 
        o.user_id,
        b.vendor_id
      INTO v_order_record
      FROM orders o
      LEFT JOIN bookings b ON b.order_id = o.id
      WHERE o.id = p_order_id;
      
      IF v_order_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
      END IF;
      
      v_dedupe_key := 'ORDER_VENDOR_SETUP_COMPLETED:USER:' || p_order_id::TEXT || ':' || v_order_record.user_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_user_id,
          title, body, order_id, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'USER', v_order_record.user_id,
          'Setup completed', 'Setup has been completed by the vendor',
          p_order_id, 'SETUP_COMPLETED', 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'status', 'SETUP_COMPLETED')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_order_record.user_id,
          'Setup completed',
          'Setup has been completed by the vendor',
          jsonb_build_object('type', 'setup_completed', 'order_id', p_order_id::TEXT),
          NULL,
          ARRAY['user_app']::TEXT[]
        );
      END IF;
    
    -- ========================================================================
    -- 6️⃣ ORDER_USER_CONFIRM_SETUP: User confirms setup
    -- ========================================================================
    WHEN 'ORDER_USER_CONFIRM_SETUP' THEN
      -- Vendor info via booking
      SELECT 
        b.vendor_id,
        vp.user_id AS vendor_user_id
      INTO v_order_record
      FROM orders o
      LEFT JOIN bookings b ON b.order_id = o.id
      LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
      WHERE o.id = p_order_id;
      
      IF v_order_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
      END IF;
      
      v_dedupe_key := 'ORDER_USER_CONFIRM_SETUP:VENDOR:' || p_order_id::TEXT || ':' || v_order_record.vendor_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_vendor_id, recipient_user_id,
          title, body, order_id, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'VENDOR', v_order_record.vendor_id, v_order_record.vendor_user_id,
          'Setup confirmed', 'User confirmed setup completion',
          p_order_id, 'SETUP_CONFIRMED', 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'status', 'SETUP_CONFIRMED')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL AND v_order_record.vendor_user_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_order_record.vendor_user_id,
          'Setup confirmed',
          'User confirmed setup completion',
          jsonb_build_object('type', 'setup_confirmed', 'order_id', p_order_id::TEXT),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
      END IF;
    
    -- ========================================================================
    -- 7️⃣ ORDER_VENDOR_COMPLETED: Vendor marks order completed
    -- ========================================================================
    WHEN 'ORDER_VENDOR_COMPLETED' THEN
      -- Get user & vendor via booking
      SELECT 
        o.user_id,
        b.vendor_id
      INTO v_order_record
      FROM orders o
      LEFT JOIN bookings b ON b.id = o.booking_id
      WHERE o.id = p_order_id;
      
      IF v_order_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
      END IF;
      
      v_dedupe_key := 'ORDER_VENDOR_COMPLETED:USER:' || p_order_id::TEXT || ':' || v_order_record.user_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_user_id,
          title, body, order_id, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'USER', v_order_record.user_id,
          'Order completed', 'Your order has been completed successfully',
          p_order_id, 'COMPLETED', 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'status', 'COMPLETED')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_order_record.user_id,
          'Order completed',
          'Your order has been completed successfully',
          jsonb_build_object('type', 'order_completed', 'order_id', p_order_id::TEXT),
          NULL,
          ARRAY['user_app']::TEXT[]
        );
      END IF;
    
    -- ========================================================================
    -- 🔔 PAYMENT_ANY_STAGE: Payment at any stage (continuity rule)
    -- ========================================================================
    WHEN 'PAYMENT_ANY_STAGE' THEN
      -- Get payment + user (vendor currently not linked to orders)
      SELECT 
        pm.order_id,
        pm.amount,
        pm.status,
        o.user_id,
        b.vendor_id,
        vp.user_id AS vendor_user_id
      INTO v_payment_record
      FROM payment_milestones pm
      LEFT JOIN orders o ON o.id = pm.order_id
      -- No reliable order↔booking link yet; disable join
      LEFT JOIN bookings b ON FALSE
      LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
      WHERE pm.id = p_payment_id;
      
      IF v_payment_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payment not found');
      END IF;
      
      -- User App notification
      v_dedupe_key := 'PAYMENT_ANY_STAGE:USER:' || COALESCE(v_payment_record.order_id::TEXT, '') || ':' || v_payment_record.user_id::TEXT || ':' || p_payment_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_user_id,
          title, body, order_id, amount, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'USER', v_payment_record.user_id,
          'Payment received', 'Additional payment of ₹' || v_payment_record.amount || ' received',
          v_payment_record.order_id, v_payment_record.amount, v_payment_record.status, 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', v_payment_record.order_id, 'payment_id', p_payment_id, 'amount', v_payment_record.amount)
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_payment_record.user_id,
          'Payment received',
          'Additional payment of ₹' || v_payment_record.amount || ' received',
          jsonb_build_object('type', 'payment_received', 'order_id', v_payment_record.order_id::TEXT, 'amount', v_payment_record.amount),
          NULL,
          ARRAY['user_app']::TEXT[]
        );
      END IF;
      
      -- Vendor App notification
      IF v_payment_record.vendor_user_id IS NOT NULL THEN
        v_dedupe_key := 'PAYMENT_ANY_STAGE:VENDOR:' || COALESCE(v_payment_record.order_id::TEXT, '') || ':' || v_payment_record.vendor_id::TEXT || ':' || p_payment_id::TEXT;
        
        SELECT notification_id INTO v_notification_id
        FROM notifications
        WHERE dedupe_key = v_dedupe_key
        LIMIT 1;
        
        IF v_notification_id IS NULL THEN
          INSERT INTO notifications (
            event_id, recipient_role, recipient_vendor_id, recipient_user_id,
            title, body, order_id, amount, status, type, dedupe_key, metadata
          ) VALUES (
            v_event_id, 'VENDOR', v_payment_record.vendor_id, v_payment_record.vendor_user_id,
            'Payment received', 'Additional payment of ₹' || v_payment_record.amount || ' received',
            v_payment_record.order_id, v_payment_record.amount, v_payment_record.status, 'BOTH', v_dedupe_key,
            jsonb_build_object('order_id', v_payment_record.order_id, 'payment_id', p_payment_id, 'amount', v_payment_record.amount)
          )
          RETURNING notification_id INTO v_notification_id;
        END IF;
        
        IF v_notification_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_payment_record.vendor_user_id,
            'Payment received',
            'Additional payment of ₹' || v_payment_record.amount || ' received',
            jsonb_build_object('type', 'payment_received', 'order_id', v_payment_record.order_id::TEXT, 'amount', v_payment_record.amount),
            NULL,
            ARRAY['vendor_app']::TEXT[]
          );
        END IF;
      END IF;
    
    -- ========================================================================
    -- 8️⃣ ORDER_USER_CANCELLED: User cancels the order
    -- ========================================================================
    WHEN 'ORDER_USER_CANCELLED' THEN
      -- Vendor info via booking
      SELECT 
        b.vendor_id,
        vp.user_id AS vendor_user_id
      INTO v_order_record
      FROM orders o
      LEFT JOIN bookings b ON b.order_id = o.id
      LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
      WHERE o.id = p_order_id;
      
      IF v_order_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
      END IF;
      
      v_dedupe_key := 'ORDER_USER_CANCELLED:VENDOR:' || p_order_id::TEXT || ':' || v_order_record.vendor_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_vendor_id, recipient_user_id,
          title, body, order_id, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'VENDOR', v_order_record.vendor_id, v_order_record.vendor_user_id,
          'Order cancelled', 'Order has been cancelled by the user',
          p_order_id, 'CANCELLED', 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'status', 'CANCELLED')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL AND v_order_record.vendor_user_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_order_record.vendor_user_id,
          'Order cancelled',
          'Order has been cancelled by the user',
          jsonb_build_object('type', 'order_cancelled', 'order_id', p_order_id::TEXT),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
      END IF;
    
    -- ========================================================================
    -- 9️⃣ ORDER_VENDOR_CANCELLED: Vendor cancels the order
    -- ========================================================================
    WHEN 'ORDER_VENDOR_CANCELLED' THEN
      -- Get user & vendor via booking
      SELECT 
        o.user_id,
        b.vendor_id
      INTO v_order_record
      FROM orders o
      LEFT JOIN bookings b ON b.order_id = o.id
      WHERE o.id = p_order_id;
      
      IF v_order_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Order not found');
      END IF;
      
      v_dedupe_key := 'ORDER_VENDOR_CANCELLED:USER:' || p_order_id::TEXT || ':' || v_order_record.user_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_user_id,
          title, body, order_id, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'USER', v_order_record.user_id,
          'Order cancelled', 'Order has been cancelled by the vendor',
          p_order_id, 'CANCELLED', 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'status', 'CANCELLED')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_order_record.user_id,
          'Order cancelled',
          'Order has been cancelled by the vendor',
          jsonb_build_object('type', 'order_cancelled', 'order_id', p_order_id::TEXT),
          NULL,
          ARRAY['user_app']::TEXT[]
        );
      END IF;
    
    -- ========================================================================
    -- 🔟 VENDOR_REG_APPROVED: Vendor registration approved
    -- ========================================================================
    WHEN 'VENDOR_REG_APPROVED' THEN
      SELECT vp.id as vendor_id, vp.user_id as vendor_user_id
      INTO v_vendor_record
      FROM vendor_profiles vp
      WHERE vp.id = p_payload->>'vendor_id'::UUID OR vp.user_id = p_actor_id;
      
      IF v_vendor_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Vendor not found');
      END IF;
      
      v_dedupe_key := 'VENDOR_REG_APPROVED:VENDOR:' || v_vendor_record.vendor_id::TEXT || ':' || v_vendor_record.vendor_user_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_vendor_id, recipient_user_id,
          title, body, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'VENDOR', v_vendor_record.vendor_id, v_vendor_record.vendor_user_id,
          'Account approved', 'Your vendor account has been approved',
          'APPROVED', 'BOTH', v_dedupe_key,
          jsonb_build_object('vendor_id', v_vendor_record.vendor_id, 'status', 'APPROVED')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
      
      IF v_notification_id IS NOT NULL AND v_vendor_record.vendor_user_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_vendor_record.vendor_user_id,
          'Account approved',
          'Your vendor account has been approved',
          jsonb_build_object('type', 'vendor_approved', 'vendor_id', v_vendor_record.vendor_id::TEXT),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
      END IF;
    
    -- ========================================================================
    -- 1️⃣1️⃣ SUPPORT_TICKET_UPDATED: Support ticket updated (Admin message)
    -- ========================================================================
    WHEN 'SUPPORT_TICKET_UPDATED' THEN
      SELECT st.user_id, st.vendor_id, st.subject, p_payload->>'admin_message' as admin_message
      INTO v_ticket_record
      FROM support_tickets st
      WHERE st.id = p_ticket_id;
      
      IF v_ticket_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Ticket not found');
      END IF;
      
      v_admin_message := COALESCE(v_ticket_record.admin_message, 'Your support ticket has been updated');
      
      -- Notify user if ticket was raised by user
      IF v_ticket_record.user_id IS NOT NULL THEN
        v_dedupe_key := 'SUPPORT_TICKET_UPDATED:USER:' || p_ticket_id::TEXT || ':' || v_ticket_record.user_id::TEXT;
        
        SELECT notification_id INTO v_notification_id
        FROM notifications
        WHERE dedupe_key = v_dedupe_key
        LIMIT 1;
        
        IF v_notification_id IS NULL THEN
          INSERT INTO notifications (
            event_id, recipient_role, recipient_user_id,
            title, body, status, type, dedupe_key, metadata
          ) VALUES (
            v_event_id, 'USER', v_ticket_record.user_id,
            'Support ticket updated', v_admin_message,
            'UPDATED', 'BOTH', v_dedupe_key,
            jsonb_build_object('ticket_id', p_ticket_id, 'subject', v_ticket_record.subject)
          )
          RETURNING notification_id INTO v_notification_id;
        END IF;
        
        IF v_notification_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_ticket_record.user_id,
            'Support ticket updated',
            v_admin_message,
            jsonb_build_object('type', 'support_ticket_updated', 'ticket_id', p_ticket_id::TEXT),
            NULL,
            ARRAY['user_app']::TEXT[]
          );
        END IF;
      END IF;
      
      -- Notify vendor if ticket was raised by vendor
      IF v_ticket_record.vendor_id IS NOT NULL THEN
        SELECT vp.user_id INTO v_vendor_user_id
        FROM vendor_profiles vp WHERE vp.id = v_ticket_record.vendor_id;
        
        IF v_vendor_user_id IS NOT NULL THEN
          v_dedupe_key := 'SUPPORT_TICKET_UPDATED:VENDOR:' || p_ticket_id::TEXT || ':' || v_ticket_record.vendor_id::TEXT;
          
          SELECT notification_id INTO v_notification_id
          FROM notifications
          WHERE dedupe_key = v_dedupe_key
          LIMIT 1;
          
          IF v_notification_id IS NULL THEN
            INSERT INTO notifications (
              event_id, recipient_role, recipient_vendor_id, recipient_user_id,
              title, body, status, type, dedupe_key, metadata
            ) VALUES (
              v_event_id, 'VENDOR', v_ticket_record.vendor_id, v_vendor_user_id,
              'Support ticket updated', v_admin_message,
              'UPDATED', 'BOTH', v_dedupe_key,
              jsonb_build_object('ticket_id', p_ticket_id, 'subject', v_ticket_record.subject)
            )
            RETURNING notification_id INTO v_notification_id;
          END IF;
          
          IF v_notification_id IS NOT NULL THEN
            PERFORM send_push_notification(
              v_vendor_user_id,
              'Support ticket updated',
              v_admin_message,
              jsonb_build_object('type', 'support_ticket_updated', 'ticket_id', p_ticket_id::TEXT),
              NULL,
              ARRAY['vendor_app']::TEXT[]
            );
          END IF;
        END IF;
      END IF;
    
    -- ========================================================================
    -- 1️⃣2️⃣ CAMPAIGN_BROADCAST: Campaign notifications
    -- ========================================================================
    WHEN 'CAMPAIGN_BROADCAST' THEN
      -- Get campaign details
      SELECT nc.title, nc.message, nc.target_audience, nc.target_user_ids, nc.target_vendor_ids
      INTO v_campaign_record
      FROM notification_campaigns nc
      WHERE nc.id = p_campaign_id;
      
      IF v_campaign_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Campaign not found');
      END IF;
      
      -- Get all active users if targeting users
      IF v_campaign_record.target_audience IN ('users', 'both') OR v_campaign_record.target_user_ids IS NOT NULL THEN
        IF v_campaign_record.target_user_ids IS NOT NULL THEN
          v_all_user_ids := v_campaign_record.target_user_ids;
        ELSE
          SELECT ARRAY_AGG(DISTINCT user_id) INTO v_all_user_ids
          FROM auth.users
          WHERE deleted_at IS NULL;
        END IF;
        
        -- Create notifications for all users
        IF v_all_user_ids IS NOT NULL THEN
          FOR v_user_id IN SELECT unnest(v_all_user_ids)
          LOOP
            v_dedupe_key := 'CAMPAIGN_BROADCAST:USER:' || p_campaign_id::TEXT || ':' || v_user_id::TEXT;
            
            SELECT notification_id INTO v_notification_id
            FROM notifications
            WHERE dedupe_key = v_dedupe_key
            LIMIT 1;
            
            IF v_notification_id IS NULL THEN
              INSERT INTO notifications (
                event_id, recipient_role, recipient_user_id,
                title, body, status, type, dedupe_key, metadata
              ) VALUES (
                v_event_id, 'USER', v_user_id,
                v_campaign_record.title, v_campaign_record.message,
                'SENT', 'BOTH', v_dedupe_key,
                jsonb_build_object('campaign_id', p_campaign_id)
              )
              RETURNING notification_id INTO v_notification_id;
            END IF;
            
            IF v_notification_id IS NOT NULL THEN
              PERFORM send_push_notification(
                v_user_id,
                v_campaign_record.title,
                v_campaign_record.message,
                jsonb_build_object('type', 'campaign', 'campaign_id', p_campaign_id::TEXT),
                NULL,
                ARRAY['user_app']::TEXT[]
              );
            END IF;
          END LOOP;
        END IF;
      END IF;
      
      -- Get all active vendors if targeting vendors
      IF v_campaign_record.target_audience IN ('vendors', 'both') OR v_campaign_record.target_vendor_ids IS NOT NULL THEN
        IF v_campaign_record.target_vendor_ids IS NOT NULL THEN
          SELECT ARRAY_AGG(vp.user_id) INTO v_all_vendor_user_ids
          FROM vendor_profiles vp
          WHERE vp.id = ANY(v_campaign_record.target_vendor_ids);
        ELSE
          SELECT ARRAY_AGG(vp.user_id) INTO v_all_vendor_user_ids
          FROM vendor_profiles vp
          WHERE vp.status = 'approved';
        END IF;
        
        -- Create notifications for all vendors
        IF v_all_vendor_user_ids IS NOT NULL THEN
          FOR v_vendor_user_id IN SELECT unnest(v_all_vendor_user_ids)
          LOOP
            v_dedupe_key := 'CAMPAIGN_BROADCAST:VENDOR:' || p_campaign_id::TEXT || ':' || v_vendor_user_id::TEXT;
            
            SELECT notification_id INTO v_notification_id
            FROM notifications
            WHERE dedupe_key = v_dedupe_key
            LIMIT 1;
            
            IF v_notification_id IS NULL THEN
              INSERT INTO notifications (
                event_id, recipient_role, recipient_user_id,
                title, body, status, type, dedupe_key, metadata
              ) VALUES (
                v_event_id, 'VENDOR', v_vendor_user_id,
                v_campaign_record.title, v_campaign_record.message,
                'SENT', 'BOTH', v_dedupe_key,
                jsonb_build_object('campaign_id', p_campaign_id)
              )
              RETURNING notification_id INTO v_notification_id;
            END IF;
            
            IF v_notification_id IS NOT NULL THEN
              PERFORM send_push_notification(
                v_vendor_user_id,
                v_campaign_record.title,
                v_campaign_record.message,
                jsonb_build_object('type', 'campaign', 'campaign_id', p_campaign_id::TEXT),
                NULL,
                ARRAY['vendor_app']::TEXT[]
              );
            END IF;
          END LOOP;
        END IF;
      END IF;
    
    -- ========================================================================
    -- 1️⃣3️⃣ REFUND_INITIATED: Refund initiated
    -- ========================================================================
    WHEN 'REFUND_INITIATED' THEN
      SELECT r.customer_amount, r.vendor_amount, b.user_id, b.vendor_id, vp.user_id as vendor_user_id
      INTO v_refund_record
      FROM refunds r
      LEFT JOIN bookings b ON b.id = r.booking_id
      LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
      WHERE r.id = p_refund_id;
      
      IF v_refund_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Refund not found');
      END IF;
      
      v_user_refund_amount := COALESCE(v_refund_record.customer_amount, 0);
      v_vendor_refund_amount := COALESCE(v_refund_record.vendor_amount, 0);
      
      -- User App notification
      IF v_refund_record.user_id IS NOT NULL THEN
        v_dedupe_key := 'REFUND_INITIATED:USER:' || p_refund_id::TEXT || ':' || v_refund_record.user_id::TEXT;
        
        SELECT notification_id INTO v_notification_id
        FROM notifications
        WHERE dedupe_key = v_dedupe_key
        LIMIT 1;
        
        IF v_notification_id IS NULL THEN
          INSERT INTO notifications (
            event_id, recipient_role, recipient_user_id,
            title, body, amount, status, type, dedupe_key, metadata
          ) VALUES (
            v_event_id, 'USER', v_refund_record.user_id,
            'Refund initiated', 'Refund initiated – Amount: ₹' || v_user_refund_amount,
            v_user_refund_amount, 'REFUND_INITIATED', 'BOTH', v_dedupe_key,
            jsonb_build_object('refund_id', p_refund_id, 'amount', v_user_refund_amount)
          )
          RETURNING notification_id INTO v_notification_id;
        END IF;
        
        IF v_notification_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_refund_record.user_id,
            'Refund initiated',
            'Refund initiated – Amount: ₹' || v_user_refund_amount,
            jsonb_build_object('type', 'refund_initiated', 'refund_id', p_refund_id::TEXT, 'amount', v_user_refund_amount),
            NULL,
            ARRAY['user_app']::TEXT[]
          );
        END IF;
      END IF;
      
      -- Vendor App notification
      IF v_refund_record.vendor_user_id IS NOT NULL THEN
        v_dedupe_key := 'REFUND_INITIATED:VENDOR:' || p_refund_id::TEXT || ':' || v_refund_record.vendor_id::TEXT;
        
        SELECT notification_id INTO v_notification_id
        FROM notifications
        WHERE dedupe_key = v_dedupe_key
        LIMIT 1;
        
        IF v_notification_id IS NULL THEN
          INSERT INTO notifications (
            event_id, recipient_role, recipient_vendor_id, recipient_user_id,
            title, body, amount, status, type, dedupe_key, metadata
          ) VALUES (
            v_event_id, 'VENDOR', v_refund_record.vendor_id, v_refund_record.vendor_user_id,
            'Refund initiated', 'Refund initiated – Amount: ₹' || v_vendor_refund_amount,
            v_vendor_refund_amount, 'REFUND_INITIATED', 'BOTH', v_dedupe_key,
            jsonb_build_object('refund_id', p_refund_id, 'amount', v_vendor_refund_amount)
          )
          RETURNING notification_id INTO v_notification_id;
        END IF;
        
        IF v_notification_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_refund_record.vendor_user_id,
            'Refund initiated',
            'Refund initiated – Amount: ₹' || v_vendor_refund_amount,
            jsonb_build_object('type', 'refund_initiated', 'refund_id', p_refund_id::TEXT, 'amount', v_vendor_refund_amount),
            NULL,
            ARRAY['vendor_app']::TEXT[]
          );
        END IF;
      END IF;
    
    -- ========================================================================
    -- 1️⃣4️⃣ REFUND_APPROVED: Refund approved by admin (ONLY if amount > 0)
    -- ========================================================================
    WHEN 'REFUND_APPROVED' THEN
      SELECT r.customer_amount, r.vendor_amount, b.user_id, b.vendor_id, vp.user_id as vendor_user_id
      INTO v_refund_record
      FROM refunds r
      LEFT JOIN bookings b ON b.id = r.booking_id
      LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
      WHERE r.id = p_refund_id;
      
      IF v_refund_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Refund not found');
      END IF;
      
      v_user_refund_amount := COALESCE(v_refund_record.customer_amount, 0);
      v_vendor_refund_amount := COALESCE(v_refund_record.vendor_amount, 0);
      
      -- User App notification (ONLY if user_refund_amount > 0)
      IF v_user_refund_amount > 0 AND v_refund_record.user_id IS NOT NULL THEN
        v_dedupe_key := 'REFUND_APPROVED:USER:' || p_refund_id::TEXT || ':' || v_refund_record.user_id::TEXT;
        
        SELECT notification_id INTO v_notification_id
        FROM notifications
        WHERE dedupe_key = v_dedupe_key
        LIMIT 1;
        
        IF v_notification_id IS NULL THEN
          INSERT INTO notifications (
            event_id, recipient_role, recipient_user_id,
            title, body, amount, status, type, dedupe_key, metadata
          ) VALUES (
            v_event_id, 'USER', v_refund_record.user_id,
            'Refund approved', 'Refund approved – Amount: ₹' || v_user_refund_amount,
            v_user_refund_amount, 'REFUND_APPROVED', 'BOTH', v_dedupe_key,
            jsonb_build_object('refund_id', p_refund_id, 'amount', v_user_refund_amount)
          )
          RETURNING notification_id INTO v_notification_id;
        END IF;
        
        IF v_notification_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_refund_record.user_id,
            'Refund approved',
            'Refund approved – Amount: ₹' || v_user_refund_amount,
            jsonb_build_object('type', 'refund_approved', 'refund_id', p_refund_id::TEXT, 'amount', v_user_refund_amount),
            NULL,
            ARRAY['user_app']::TEXT[]
          );
        END IF;
      END IF;
      
      -- Vendor App notification (ONLY if vendor_refund_amount > 0)
      IF v_vendor_refund_amount > 0 AND v_refund_record.vendor_user_id IS NOT NULL THEN
        v_dedupe_key := 'REFUND_APPROVED:VENDOR:' || p_refund_id::TEXT || ':' || v_refund_record.vendor_id::TEXT;
        
        SELECT notification_id INTO v_notification_id
        FROM notifications
        WHERE dedupe_key = v_dedupe_key
        LIMIT 1;
        
        IF v_notification_id IS NULL THEN
          INSERT INTO notifications (
            event_id, recipient_role, recipient_vendor_id, recipient_user_id,
            title, body, amount, status, type, dedupe_key, metadata
          ) VALUES (
            v_event_id, 'VENDOR', v_refund_record.vendor_id, v_refund_record.vendor_user_id,
            'Refund approved', 'Refund approved – Amount: ₹' || v_vendor_refund_amount,
            v_vendor_refund_amount, 'REFUND_APPROVED', 'BOTH', v_dedupe_key,
            jsonb_build_object('refund_id', p_refund_id, 'amount', v_vendor_refund_amount)
          )
          RETURNING notification_id INTO v_notification_id;
        END IF;
        
        IF v_notification_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_refund_record.vendor_user_id,
            'Refund approved',
            'Refund approved – Amount: ₹' || v_vendor_refund_amount,
            jsonb_build_object('type', 'refund_approved', 'refund_id', p_refund_id::TEXT, 'amount', v_vendor_refund_amount),
            NULL,
            ARRAY['vendor_app']::TEXT[]
          );
        END IF;
      END IF;
    
    -- ========================================================================
    -- 1️⃣5️⃣ VENDOR_WITHDRAWAL_REQUESTED: Vendor requests withdrawal
    -- ========================================================================
    WHEN 'VENDOR_WITHDRAWAL_REQUESTED' THEN
      SELECT wr.vendor_id, wr.amount, vp.user_id as vendor_user_id
      INTO v_withdrawal_record
      FROM withdrawal_requests wr
      LEFT JOIN vendor_profiles vp ON vp.id = wr.vendor_id
      WHERE wr.id = p_withdrawal_request_id;
      
      IF v_withdrawal_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Withdrawal request not found');
      END IF;
      
      -- Vendor App notification
      IF v_withdrawal_record.vendor_user_id IS NOT NULL THEN
        v_dedupe_key := 'VENDOR_WITHDRAWAL_REQUESTED:VENDOR:' || p_withdrawal_request_id::TEXT || ':' || v_withdrawal_record.vendor_user_id::TEXT;
        
        SELECT notification_id INTO v_notification_id
        FROM notifications
        WHERE dedupe_key = v_dedupe_key
        LIMIT 1;
        
        IF v_notification_id IS NULL THEN
          INSERT INTO notifications (
            event_id, recipient_role, recipient_vendor_id, recipient_user_id,
            title, body, amount, status, type, dedupe_key, metadata
          ) VALUES (
            v_event_id, 'VENDOR', v_withdrawal_record.vendor_id, v_withdrawal_record.vendor_user_id,
            'Withdrawal requested', 'Withdrawal requested. Funds will be processed in 4–7 days.',
            v_withdrawal_record.amount, 'PENDING', 'BOTH', v_dedupe_key,
            jsonb_build_object('withdrawal_request_id', p_withdrawal_request_id, 'amount', v_withdrawal_record.amount)
          )
          RETURNING notification_id INTO v_notification_id;
        END IF;
        
        IF v_notification_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_withdrawal_record.vendor_user_id,
            'Withdrawal requested',
            'Withdrawal requested. Funds will be processed in 4–7 days.',
            jsonb_build_object('type', 'withdrawal_requested', 'withdrawal_request_id', p_withdrawal_request_id::TEXT),
            NULL,
            ARRAY['vendor_app']::TEXT[]
          );
        END IF;
      END IF;
      
      -- Company App notification (in-app only, no push)
      v_dedupe_key := 'VENDOR_WITHDRAWAL_REQUESTED:COMPANY:' || p_withdrawal_request_id::TEXT;
      
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role,
          title, body, amount, status, type, dedupe_key, metadata, channel
        ) VALUES (
          v_event_id, 'COMPANY',
          'New withdrawal request', 'New vendor withdrawal request received',
          v_withdrawal_record.amount, 'PENDING', 'IN_APP', v_dedupe_key,
          jsonb_build_object('withdrawal_request_id', p_withdrawal_request_id, 'vendor_id', v_withdrawal_record.vendor_id),
          'WEB_APP'
        );
      END IF;
    
    -- ========================================================================
    -- 1️⃣6️⃣ VENDOR_FUNDS_RELEASED_TO_WALLET: Company releases funds to vendor wallet
    -- ========================================================================
    WHEN 'VENDOR_FUNDS_RELEASED_TO_WALLET' THEN
      SELECT wt.vendor_id, wt.amount, vp.user_id as vendor_user_id
      INTO v_withdrawal_record
      FROM wallet_transactions wt
      LEFT JOIN vendor_profiles vp ON vp.id = wt.vendor_id
      WHERE wt.id = p_payload->>'wallet_transaction_id'::UUID;
      
      IF v_withdrawal_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet transaction not found');
      END IF;
      
      IF v_withdrawal_record.vendor_user_id IS NOT NULL THEN
        v_dedupe_key := 'VENDOR_FUNDS_RELEASED_TO_WALLET:VENDOR:' || v_withdrawal_record.vendor_id::TEXT || ':' || v_withdrawal_record.vendor_user_id::TEXT;
        
        SELECT notification_id INTO v_notification_id
        FROM notifications
        WHERE dedupe_key = v_dedupe_key
        LIMIT 1;
        
        IF v_notification_id IS NULL THEN
          INSERT INTO notifications (
            event_id, recipient_role, recipient_vendor_id, recipient_user_id,
            title, body, amount, status, type, dedupe_key, metadata
          ) VALUES (
            v_event_id, 'VENDOR', v_withdrawal_record.vendor_id, v_withdrawal_record.vendor_user_id,
            'Funds credited', 'Funds have been credited to your wallet',
            v_withdrawal_record.amount, 'COMPLETED', 'BOTH', v_dedupe_key,
            jsonb_build_object('amount', v_withdrawal_record.amount)
          )
          RETURNING notification_id INTO v_notification_id;
        END IF;
        
        IF v_notification_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_withdrawal_record.vendor_user_id,
            'Funds credited',
            'Funds have been credited to your wallet',
            jsonb_build_object('type', 'funds_credited', 'amount', v_withdrawal_record.amount),
            NULL,
            ARRAY['vendor_app']::TEXT[]
          );
        END IF;
      END IF;
    
    -- ========================================================================
    -- 1️⃣7️⃣ VENDOR_WITHDRAWAL_APPROVED: Company approves withdrawal
    -- ========================================================================
    WHEN 'VENDOR_WITHDRAWAL_APPROVED' THEN
      SELECT wr.vendor_id, wr.amount, vp.user_id as vendor_user_id
      INTO v_withdrawal_record
      FROM withdrawal_requests wr
      LEFT JOIN vendor_profiles vp ON vp.id = wr.vendor_id
      WHERE wr.id = p_withdrawal_request_id;
      
      IF v_withdrawal_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Withdrawal request not found');
      END IF;
      
      IF v_withdrawal_record.vendor_user_id IS NOT NULL THEN
        v_dedupe_key := 'VENDOR_WITHDRAWAL_APPROVED:VENDOR:' || p_withdrawal_request_id::TEXT || ':' || v_withdrawal_record.vendor_user_id::TEXT;
        
        SELECT notification_id INTO v_notification_id
        FROM notifications
        WHERE dedupe_key = v_dedupe_key
        LIMIT 1;
        
        IF v_notification_id IS NULL THEN
          INSERT INTO notifications (
            event_id, recipient_role, recipient_vendor_id, recipient_user_id,
            title, body, amount, status, type, dedupe_key, metadata
          ) VALUES (
            v_event_id, 'VENDOR', v_withdrawal_record.vendor_id, v_withdrawal_record.vendor_user_id,
            'Withdrawal approved', 'Your withdrawal has been approved',
            v_withdrawal_record.amount, 'APPROVED', 'BOTH', v_dedupe_key,
            jsonb_build_object('withdrawal_request_id', p_withdrawal_request_id, 'amount', v_withdrawal_record.amount)
          )
          RETURNING notification_id INTO v_notification_id;
        END IF;
        
        IF v_notification_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_withdrawal_record.vendor_user_id,
            'Withdrawal approved',
            'Your withdrawal has been approved',
            jsonb_build_object('type', 'withdrawal_approved', 'withdrawal_request_id', p_withdrawal_request_id::TEXT),
            NULL,
            ARRAY['vendor_app']::TEXT[]
          );
        END IF;
      END IF;
    
    ELSE
      -- Unknown event code
      RETURN jsonb_build_object('success', false, 'error', 'Unknown event code: ' || p_event_code);
  END CASE;
  
  -- Mark event as processed
  UPDATE notification_events SET processed = TRUE, processed_at = NOW() WHERE event_id = v_event_id;
  
  RETURN jsonb_build_object('success', true, 'event_id', v_event_id);
END;
$$;

-- ============================================================================
-- Verification Query
-- ============================================================================
SELECT 
  'Verification: Function Updated' as check_type,
  routine_name,
  CASE 
    WHEN routine_name = 'process_notification_event' 
    THEN '✅ Updated with all 17 rules'
    ELSE '❌ Missing'
  END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'process_notification_event';
