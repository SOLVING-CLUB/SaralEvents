-- ============================================================================
-- AUTOMATED NOTIFICATION TRIGGERS (FIXED VERSION)
-- Comprehensive notification system for User App and Vendor App
-- ============================================================================
-- This version uses pg_net extension (Supabase's native extension)
-- Run ENABLE_PG_NET_EXTENSION.sql FIRST before running this file

-- ============================================================================
-- PREREQUISITES
-- ============================================================================
-- 1. Enable pg_net extension:
--    CREATE EXTENSION IF NOT EXISTS pg_net;
--
-- 2. Set environment variables:
--    ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
--    ALTER DATABASE postgres SET app.supabase_service_role_key = 'your-service-role-key';

-- ============================================================================
-- HELPER FUNCTION: Send Push Notification via Edge Function
-- ============================================================================
-- Uses pg_net extension (Supabase's native extension for HTTP requests)
CREATE OR REPLACE FUNCTION send_push_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT '{}'::JSONB,
  p_image_url TEXT DEFAULT NULL,
  p_app_types TEXT[] DEFAULT ARRAY['user_app', 'vendor_app']::TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_role_key TEXT;
  v_request_id BIGINT;
BEGIN
  -- Get Supabase URL and Service Role Key from environment
  v_supabase_url := current_setting('app.supabase_url', true);
  v_service_role_key := current_setting('app.supabase_service_role_key', true);

  IF v_supabase_url IS NULL THEN
    v_supabase_url := current_setting('app.supabase_url');
  END IF;

  IF v_service_role_key IS NULL THEN
    v_service_role_key := current_setting('app.supabase_service_role_key');
  END IF;

  -- Use pg_net extension (Supabase's native extension)
  -- pg_net.http_post returns a request ID (async operation)
  SELECT id INTO v_request_id
  FROM net.http_post(
    url := v_supabase_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_service_role_key,
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'userId', p_user_id,
      'title', p_title,
      'body', p_body,
      'data', p_data,
      'imageUrl', COALESCE(p_image_url, ''),
      'appTypes', p_app_types
    )
  );
  
  -- Return success with request ID
  -- Note: pg_net is async, so we return immediately
  -- The actual HTTP call happens asynchronously
  RETURN jsonb_build_object(
    'success', true, 
    'request_id', v_request_id,
    'message', 'Notification request queued'
  );
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
    RETURN jsonb_build_object(
      'error', SQLERRM, 
      'success', false,
      'message', 'Please enable pg_net extension: CREATE EXTENSION IF NOT EXISTS pg_net;'
    );
END;
$$;

-- ============================================================================
-- TRIGGER 1: Cart Abandonment Notification (6 hours)
-- ============================================================================
-- Sends notification when items remain in cart for 6 hours

-- Add column to track if notification was sent (optional optimization)
ALTER TABLE cart_items ADD COLUMN IF NOT EXISTS abandonment_notified_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION notify_cart_abandonment()
RETURNS TRIGGER AS $$
DECLARE
  v_service_name TEXT;
  v_cart_count INTEGER;
BEGIN
  -- Only trigger for active cart items that are 6+ hours old
  -- Check if notification was already sent to prevent duplicates
  IF NEW.status = 'active' AND 
     NEW.created_at <= NOW() - INTERVAL '6 hours' AND
     (NEW.abandonment_notified_at IS NULL OR NEW.abandonment_notified_at < NEW.created_at + INTERVAL '6 hours') THEN
    
    -- Get service name
    SELECT name INTO v_service_name
    FROM services
    WHERE id = NEW.service_id;

    -- Count total items in cart for this user
    SELECT COUNT(*) INTO v_cart_count
    FROM cart_items
    WHERE user_id = NEW.user_id
    AND status = 'active'
    AND created_at <= NOW() - INTERVAL '6 hours';

    -- Send notification to user
    PERFORM send_push_notification(
      NEW.user_id,
      'Complete Your Order',
      COALESCE(
        CASE 
          WHEN v_cart_count > 1 THEN 
            'You have ' || v_cart_count || ' items waiting in your cart. Complete your order now!'
          ELSE 
            'Your ' || COALESCE(v_service_name, 'item') || ' is waiting in your cart. Complete your order now!'
        END,
        'Complete your order to secure your booking!'
      ),
      jsonb_build_object(
        'type', 'cart_abandonment',
        'cart_item_id', NEW.id::TEXT,
        'service_id', NEW.service_id::TEXT,
        'cart_count', v_cart_count
      ),
      NULL,
      ARRAY['user_app']::TEXT[]
    );

    -- Mark that notification was sent
    NEW.abandonment_notified_at = NOW();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for cart abandonment
DROP TRIGGER IF EXISTS cart_abandonment_notification ON cart_items;
CREATE TRIGGER cart_abandonment_notification
  BEFORE UPDATE ON cart_items
  FOR EACH ROW
  WHEN (NEW.status = 'active' AND NEW.created_at <= NOW() - INTERVAL '6 hours')
  EXECUTE FUNCTION notify_cart_abandonment();

-- ============================================================================
-- TRIGGER 2: Order Status Change Notification
-- ============================================================================
-- Sends notification when booking status changes (consolidated, no duplicates)

CREATE OR REPLACE FUNCTION notify_booking_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_service_name TEXT;
  v_vendor_user_id UUID;
BEGIN
  -- Only send notification if status actually changed
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    -- Get service name
    SELECT name INTO v_service_name
    FROM services
    WHERE id = NEW.service_id;

    -- Get vendor's user_id for vendor notifications
    SELECT user_id INTO v_vendor_user_id
    FROM vendor_profiles
    WHERE id = NEW.vendor_id;

    -- Notify user about status change
    PERFORM send_push_notification(
      NEW.user_id,
      CASE NEW.status
        WHEN 'confirmed' THEN 'Booking Confirmed'
        WHEN 'completed' THEN 'Order Completed'
        WHEN 'cancelled' THEN 'Booking Cancelled'
        ELSE 'Order Update'
      END,
      CASE NEW.status
        WHEN 'confirmed' THEN 
          COALESCE('Your booking for ' || v_service_name || ' has been confirmed!', 'Your booking has been confirmed!')
        WHEN 'completed' THEN 
          COALESCE('Your order for ' || v_service_name || ' has been completed. Thank you!', 'Your order has been completed.')
        WHEN 'cancelled' THEN 
          'Your booking has been cancelled. Refund will be processed as per policy.'
        ELSE 
          COALESCE('Your order for ' || v_service_name || ' status has been updated to ' || NEW.status, 
                   'Your order status has been updated to ' || NEW.status)
      END,
      jsonb_build_object(
        'type', 'booking_status_change',
        'booking_id', NEW.id::TEXT,
        'status', NEW.status,
        'old_status', OLD.status,
        'service_id', NEW.service_id::TEXT
      ),
      NULL,
      ARRAY['user_app']::TEXT[]
    );

    -- Notify vendor about status change (if vendor user_id exists)
    IF v_vendor_user_id IS NOT NULL THEN
      PERFORM send_push_notification(
        v_vendor_user_id,
        CASE NEW.status
          WHEN 'confirmed' THEN 'New Booking Confirmed'
          WHEN 'completed' THEN 'Booking Completed'
          WHEN 'cancelled' THEN 'Booking Cancelled'
          ELSE 'Booking Status Update'
        END,
        CASE NEW.status
          WHEN 'confirmed' THEN 
            COALESCE('New booking confirmed for ' || v_service_name, 'New booking confirmed')
          WHEN 'completed' THEN 
            COALESCE('Booking for ' || v_service_name || ' has been completed', 'Booking completed')
          WHEN 'cancelled' THEN 
            'A booking has been cancelled'
          ELSE 
            COALESCE('Booking status updated to ' || NEW.status, 'Booking status updated')
        END,
        jsonb_build_object(
          'type', 'booking_status_change',
          'booking_id', NEW.id::TEXT,
          'status', NEW.status,
          'old_status', OLD.status,
          'service_id', NEW.service_id::TEXT
        ),
        NULL,
        ARRAY['vendor_app']::TEXT[]
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers to avoid duplicates
DROP TRIGGER IF EXISTS booking_status_notification_user ON bookings;
DROP TRIGGER IF EXISTS booking_status_notification_vendor ON bookings;
DROP TRIGGER IF EXISTS order_status_notification_user ON bookings;
DROP TRIGGER IF EXISTS order_status_notification ON bookings;

-- Create single consolidated trigger
CREATE TRIGGER booking_status_change_notification
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_booking_status_change();

-- ============================================================================
-- TRIGGER 3: Payment Success Notification
-- ============================================================================
-- Sends notification when payment milestone status changes to 'paid' or 'held_in_escrow'

CREATE OR REPLACE FUNCTION notify_payment_success()
RETURNS TRIGGER AS $$
DECLARE
  v_booking RECORD;
  v_service_name TEXT;
  v_vendor_user_id UUID;
BEGIN
  -- Only notify on successful payment (paid or held_in_escrow)
  IF (NEW.status IN ('paid', 'held_in_escrow')) AND 
     (OLD.status IS NULL OR OLD.status NOT IN ('paid', 'held_in_escrow')) THEN
    
    -- Get booking details
    SELECT * INTO v_booking
    FROM bookings
    WHERE id = NEW.booking_id;

    IF v_booking IS NOT NULL THEN
      -- Get service name
      SELECT name INTO v_service_name
      FROM services
      WHERE id = v_booking.service_id;

      -- Get vendor's user_id
      SELECT user_id INTO v_vendor_user_id
      FROM vendor_profiles
      WHERE id = v_booking.vendor_id;

      -- Notify user about payment success
      PERFORM send_push_notification(
        v_booking.user_id,
        'Payment Successful',
        COALESCE(
          'Payment of ₹' || NEW.amount::TEXT || ' for ' || v_service_name || ' has been processed successfully',
          'Payment of ₹' || NEW.amount::TEXT || ' has been processed successfully'
        ),
        jsonb_build_object(
          'type', 'payment_success',
          'booking_id', NEW.booking_id::TEXT,
          'milestone_id', NEW.id::TEXT,
          'milestone_type', NEW.milestone_type,
          'amount', NEW.amount::TEXT,
          'status', NEW.status
        ),
        NULL,
        ARRAY['user_app']::TEXT[]
      );

      -- Notify vendor about payment received
      IF v_vendor_user_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_vendor_user_id,
          'Payment Received',
          COALESCE(
            'Payment of ₹' || NEW.amount::TEXT || ' received for ' || v_service_name,
            'Payment of ₹' || NEW.amount::TEXT || ' received'
          ),
          jsonb_build_object(
            'type', 'payment_received',
            'booking_id', NEW.booking_id::TEXT,
            'milestone_id', NEW.id::TEXT,
            'milestone_type', NEW.milestone_type,
            'amount', NEW.amount::TEXT,
            'status', NEW.status
          ),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers to avoid duplicates
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;

-- Create trigger
CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  WHEN (NEW.status IN ('paid', 'held_in_escrow') AND 
        (OLD.status IS NULL OR OLD.status NOT IN ('paid', 'held_in_escrow')))
  EXECUTE FUNCTION notify_payment_success();

-- ============================================================================
-- TRIGGER 4: Refund Initiated Notification
-- ============================================================================
-- Sends notification when refund is created (status = 'pending')

CREATE OR REPLACE FUNCTION notify_refund_initiated()
RETURNS TRIGGER AS $$
DECLARE
  v_booking RECORD;
  v_service_name TEXT;
  v_vendor_user_id UUID;
BEGIN
  -- Only notify when refund is first created (status = 'pending')
  IF NEW.status = 'pending' AND (OLD.status IS NULL OR OLD.status != 'pending') THEN
    -- Get booking details
    SELECT * INTO v_booking
    FROM bookings
    WHERE id = NEW.booking_id;

    IF v_booking IS NOT NULL THEN
      -- Get service name
      SELECT name INTO v_service_name
      FROM services
      WHERE id = v_booking.service_id;

      -- Get vendor's user_id
      SELECT user_id INTO v_vendor_user_id
      FROM vendor_profiles
      WHERE id = v_booking.vendor_id;

      -- Notify user about refund initiation
      PERFORM send_push_notification(
        v_booking.user_id,
        'Refund Initiated',
        COALESCE(
          'Refund of ₹' || NEW.refund_amount::TEXT || ' has been initiated for your ' || v_service_name || ' booking',
          'Refund of ₹' || NEW.refund_amount::TEXT || ' has been initiated'
        ),
        jsonb_build_object(
          'type', 'refund_initiated',
          'refund_id', NEW.id::TEXT,
          'booking_id', NEW.booking_id::TEXT,
          'refund_amount', NEW.refund_amount::TEXT,
          'cancelled_by', NEW.cancelled_by,
          'status', NEW.status
        ),
        NULL,
        ARRAY['user_app']::TEXT[]
      );

      -- Notify vendor if they cancelled
      IF NEW.cancelled_by = 'vendor' AND v_vendor_user_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_vendor_user_id,
          'Refund Processed',
          COALESCE(
            'Refund of ₹' || NEW.refund_amount::TEXT || ' processed for ' || v_service_name || ' booking',
            'Refund of ₹' || NEW.refund_amount::TEXT || ' processed'
          ),
          jsonb_build_object(
            'type', 'refund_initiated',
            'refund_id', NEW.id::TEXT,
            'booking_id', NEW.booking_id::TEXT,
            'refund_amount', NEW.refund_amount::TEXT
          ),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS refund_initiated_notification ON refunds;
CREATE TRIGGER refund_initiated_notification
  AFTER INSERT ON refunds
  FOR EACH ROW
  WHEN (NEW.status = 'pending')
  EXECUTE FUNCTION notify_refund_initiated();

-- ============================================================================
-- TRIGGER 5: Refund Completed Notification
-- ============================================================================
-- Sends notification when refund status changes to 'completed'

CREATE OR REPLACE FUNCTION notify_refund_completed()
RETURNS TRIGGER AS $$
DECLARE
  v_booking RECORD;
  v_service_name TEXT;
BEGIN
  -- Only notify when refund status changes to 'completed'
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    -- Get booking details
    SELECT * INTO v_booking
    FROM bookings
    WHERE id = NEW.booking_id;

    IF v_booking IS NOT NULL THEN
      -- Get service name
      SELECT name INTO v_service_name
      FROM services
      WHERE id = v_booking.service_id;

      -- Notify user about refund completion
      PERFORM send_push_notification(
        v_booking.user_id,
        'Refund Completed',
        COALESCE(
          'Refund of ₹' || NEW.refund_amount::TEXT || ' for your ' || v_service_name || ' booking has been processed and credited to your account',
          'Refund of ₹' || NEW.refund_amount::TEXT || ' has been processed and credited to your account'
        ),
        jsonb_build_object(
          'type', 'refund_completed',
          'refund_id', NEW.id::TEXT,
          'booking_id', NEW.booking_id::TEXT,
          'refund_amount', NEW.refund_amount::TEXT,
          'processed_at', NEW.processed_at::TEXT
        ),
        NULL,
        ARRAY['user_app']::TEXT[]
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS refund_completed_notification ON refunds;
CREATE TRIGGER refund_completed_notification
  AFTER UPDATE ON refunds
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed'))
  EXECUTE FUNCTION notify_refund_completed();

-- ============================================================================
-- CLEANUP: Remove Old/Duplicate Triggers
-- ============================================================================
DROP TRIGGER IF EXISTS order_status_notification_user ON orders;
DROP TRIGGER IF EXISTS order_status_notification ON orders;
DROP TRIGGER IF EXISTS booking_confirmation_notification ON bookings;
DROP TRIGGER IF EXISTS new_order_notification_vendor ON orders;

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- Active Triggers:
-- 1. cart_abandonment_notification - Cart items (6 hours)
-- 2. booking_status_change_notification - Booking status changes (consolidated)
-- 3. payment_success_notification - Payment milestones (paid/held_in_escrow)
-- 4. refund_initiated_notification - Refunds (when created)
-- 5. refund_completed_notification - Refunds (when completed)
--
-- All triggers send notifications to both user_app and vendor_app as appropriate
-- No duplicate notifications - each event has a single trigger
--
-- IMPORTANT: Requires pg_net extension
-- Run: CREATE EXTENSION IF NOT EXISTS pg_net; (or use ENABLE_PG_NET_EXTENSION.sql)
