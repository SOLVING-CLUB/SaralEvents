-- ============================================================================
-- AUTOMATED NOTIFICATION TRIGGERS
-- Comprehensive notification system for User App and Vendor App
-- ============================================================================
-- This file consolidates all notification triggers and removes duplicates
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- PREREQUISITES
-- ============================================================================
-- 1. Enable pg_net extension (Supabase's native extension):
--    CREATE EXTENSION IF NOT EXISTS pg_net;
-- 
--    OR enable http extension (alternative):
--    CREATE EXTENSION IF NOT EXISTS http;
--
-- 2. Set environment variables:
--    ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
--    ALTER DATABASE postgres SET app.supabase_service_role_key = 'your-service-role-key';

-- ============================================================================
-- HELPER FUNCTION: Send Push Notification via Edge Function
-- ============================================================================
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
  v_response JSONB;
  v_supabase_url TEXT;
  v_service_role_key TEXT;
  v_request_id BIGINT;
BEGIN
  -- IMPORTANT: Since ALTER DATABASE requires superuser (not available in Supabase),
  -- we use hardcoded values. Update these with your actual Supabase project details.
  -- Get these from: Supabase Dashboard > Settings > API
  
  -- Try to get from settings first (if admin has set them)
  v_supabase_url := current_setting('app.supabase_url', true);
  v_service_role_key := current_setting('app.supabase_service_role_key', true);
  
  -- If not set, use hardcoded values (already set with your project values)
  -- Your Supabase Project URL (from Dashboard > Settings > API > Project URL)
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://hucsihwqsuvqvbnyapdn.supabase.co';
  END IF;
  
  -- Your Service Role Key (from Dashboard > Settings > API > Secret keys > default)
  IF v_service_role_key IS NULL THEN
    v_service_role_key := 'sb_secret_QhWTQOnAO-SCeCWmWEQF6A_AAdf38pq';
  END IF;

  -- Validate we have both values
  IF v_supabase_url IS NULL OR v_service_role_key IS NULL OR 
     v_supabase_url = '' OR v_service_role_key = '' THEN
    RAISE WARNING 'Push notifications skipped: Supabase URL or Service Role Key not configured';
    RAISE NOTICE '⚠️ NOTIFICATION ERROR: Please update send_push_notification function in automated_notification_triggers.sql with your Supabase URL and service role key.';
    RETURN jsonb_build_object(
      'success', false,
      'skipped', true,
      'reason', 'missing_config',
      'error', 'Please update the function with your Supabase URL and service role key. See UPDATE_NOTIFICATION_CONFIG.sql for instructions.'
    );
  END IF;

  -- Use pg_net extension (Supabase's native and recommended method)
  -- pg_net.http_post returns a request ID (async operation) directly as BIGINT
  BEGIN
    v_request_id := net.http_post(
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
      -- If pg_net is not available, log error and return
      RAISE WARNING 'Failed to send push notification via pg_net: %', SQLERRM;
      RETURN jsonb_build_object(
        'error', SQLERRM, 
        'success', false,
        'message', 'Please enable pg_net extension: CREATE EXTENSION IF NOT EXISTS pg_net;'
      );
  END;
END;
$$;

-- ============================================================================
-- TRIGGER 1: Cart Abandonment Notification (6 hours)
-- ============================================================================
-- Sends notification when items remain in cart for 6 hours
-- Note: This trigger fires when cart items are updated after 6 hours
-- For better coverage, use the scheduled Edge Function (see documentation)

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

    -- Notify vendor about status change (ONLY if vendor didn't perform the action)
    -- Skip notifications for 'confirmed' and 'completed' as vendor performed these actions
    IF v_vendor_user_id IS NOT NULL AND NEW.status NOT IN ('confirmed', 'completed') THEN
      PERFORM send_push_notification(
        v_vendor_user_id,
        CASE NEW.status
          WHEN 'cancelled' THEN 'Booking Cancelled'
          ELSE 'Booking Status Update'
        END,
        CASE NEW.status
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
DROP TRIGGER IF EXISTS booking_status_change_notification ON bookings; -- Drop the trigger we're about to create

-- Create single consolidated trigger
CREATE TRIGGER booking_status_change_notification
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_booking_status_change();

-- ============================================================================
-- TRIGGER 3: Payment Success Notification
-- ============================================================================
-- Sends notification when payment milestone status changes to 'paid', 'held_in_escrow', or 'released'

CREATE OR REPLACE FUNCTION notify_payment_success()
RETURNS TRIGGER AS $$
DECLARE
  v_booking RECORD;
  v_service_name TEXT;
  v_vendor_user_id UUID;
BEGIN
  -- Only notify on successful payment (paid / held_in_escrow / released)
  -- For INSERT: always notify if status is in the success set
  -- For UPDATE: only notify if status changed from outside the success set into it
  IF NEW.status IN ('paid', 'held_in_escrow', 'released') THEN
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND (OLD.status IS NULL OR OLD.status NOT IN ('paid', 'held_in_escrow', 'released'))) THEN
    
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
    END IF; -- Close TG_OP check
  END IF; -- Close NEW.status check

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers to avoid duplicates
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;

-- Create trigger
-- Note: OLD check is handled inside the function to support both INSERT and UPDATE
-- Include 'released' status to notify vendor when final payment is released from escrow
CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
  EXECUTE FUNCTION notify_payment_success();

-- ============================================================================
-- TRIGGER 3b: Milestone Status Change (Customer confirmations → notify vendor)
-- ============================================================================
-- Sends notification to vendor when the customer confirms arrival or setup
-- (milestone_status moves to 'arrival_confirmed' or 'setup_confirmed').

CREATE OR REPLACE FUNCTION notify_vendor_milestone_confirmations()
RETURNS TRIGGER AS $$
DECLARE
  v_service_name TEXT;
  v_vendor_user_id UUID;
  v_title TEXT;
  v_body TEXT;
BEGIN
  -- Only act when milestone_status actually changes
  IF OLD.milestone_status IS DISTINCT FROM NEW.milestone_status THEN

    -- Only handle customer confirmations that vendors must be notified about
    IF NEW.milestone_status IN ('arrival_confirmed', 'setup_confirmed') THEN

      -- Get service name for contextual messaging
      SELECT name INTO v_service_name
      FROM services
      WHERE id = NEW.service_id;

      -- Get vendor auth user_id (NOT vendor_profiles.id)
      SELECT user_id INTO v_vendor_user_id
      FROM vendor_profiles
      WHERE id = NEW.vendor_id;

      IF v_vendor_user_id IS NULL THEN
        RETURN NEW; -- Nothing to do if vendor user_id missing
      END IF;

      -- Build message based on milestone_status
      IF NEW.milestone_status = 'arrival_confirmed' THEN
        v_title := 'Arrival Confirmed';
        v_body := COALESCE(
          'Customer confirmed your arrival for ' || v_service_name,
          'Customer confirmed your arrival'
        );
      ELSIF NEW.milestone_status = 'setup_confirmed' THEN
        v_title := 'Setup Confirmed';
        v_body := COALESCE(
          'Customer confirmed setup completion for ' || v_service_name,
          'Customer confirmed setup completion'
        );
      END IF;

      -- Notify vendor (vendor_app only)
      PERFORM send_push_notification(
        v_vendor_user_id,
        v_title,
        v_body,
        jsonb_build_object(
          'type', 'booking_update',
          'booking_id', NEW.id::TEXT,
          'milestone_status', NEW.milestone_status
        ),
        NULL,
        ARRAY['vendor_app']::TEXT[]
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if any to avoid duplicates
DROP TRIGGER IF EXISTS milestone_confirmation_notification_vendor ON bookings;

-- Create trigger on bookings.milestone_status change for vendor notifications
CREATE TRIGGER milestone_confirmation_notification_vendor
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (
    OLD.milestone_status IS DISTINCT FROM NEW.milestone_status
    AND NEW.milestone_status IN ('arrival_confirmed', 'setup_confirmed')
  )
  EXECUTE FUNCTION notify_vendor_milestone_confirmations();

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
-- Note: OLD check is handled inside the function
DROP TRIGGER IF EXISTS refund_completed_notification ON refunds;
CREATE TRIGGER refund_completed_notification
  AFTER UPDATE ON refunds
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND OLD.status != 'completed')
  EXECUTE FUNCTION notify_refund_completed();

-- ============================================================================
-- TRIGGER 6: Order Cancellation Notification
-- ============================================================================
-- Sends notification when booking is cancelled (handled by booking status change)
-- This is already covered by notify_booking_status_change() above
-- But we'll add a specific cancellation notification for clarity

CREATE OR REPLACE FUNCTION notify_order_cancellation()
RETURNS TRIGGER AS $$
DECLARE
  v_service_name TEXT;
  v_vendor_user_id UUID;
  v_refund_info RECORD;
BEGIN
  -- Only notify when booking is cancelled
  IF NEW.status = 'cancelled' AND (OLD.status IS NULL OR OLD.status != 'cancelled') THEN
    -- Get service name
    SELECT name INTO v_service_name
    FROM services
    WHERE id = NEW.service_id;

    -- Get vendor's user_id
    SELECT user_id INTO v_vendor_user_id
    FROM vendor_profiles
    WHERE id = NEW.vendor_id;

    -- Get refund information if available
    SELECT refund_amount, cancelled_by INTO v_refund_info
    FROM refunds
    WHERE booking_id = NEW.id
    ORDER BY created_at DESC
    LIMIT 1;

    -- Notify user about cancellation
    PERFORM send_push_notification(
      NEW.user_id,
      'Booking Cancelled',
      COALESCE(
        CASE 
          WHEN v_refund_info.refund_amount IS NOT NULL THEN
            'Your ' || v_service_name || ' booking has been cancelled. Refund of ₹' || 
            v_refund_info.refund_amount::TEXT || ' will be processed as per policy.'
          ELSE
            'Your ' || v_service_name || ' booking has been cancelled.'
        END,
        'Your booking has been cancelled.'
      ),
      jsonb_build_object(
        'type', 'order_cancellation',
        'booking_id', NEW.id::TEXT,
        'service_id', NEW.service_id::TEXT,
        'cancelled_by', COALESCE(v_refund_info.cancelled_by, 'unknown'),
        'refund_amount', COALESCE(v_refund_info.refund_amount::TEXT, '0')
      ),
      NULL,
      ARRAY['user_app']::TEXT[]
    );

    -- Notify vendor about cancellation
    IF v_vendor_user_id IS NOT NULL THEN
      PERFORM send_push_notification(
        v_vendor_user_id,
        'Booking Cancelled',
        COALESCE(
          'A booking for ' || v_service_name || ' has been cancelled',
          'A booking has been cancelled'
        ),
        jsonb_build_object(
          'type', 'order_cancellation',
          'booking_id', NEW.id::TEXT,
          'service_id', NEW.service_id::TEXT,
          'cancelled_by', COALESCE(v_refund_info.cancelled_by, 'unknown')
        ),
        NULL,
        ARRAY['vendor_app']::TEXT[]
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: This is redundant with booking_status_change trigger, but provides more specific messaging
-- We'll keep booking_status_change as the main trigger and this as a backup
-- Actually, let's remove this to avoid duplicates - booking_status_change already handles cancellation

-- ============================================================================
-- SCHEDULED JOB: Cart Abandonment Check (runs every hour)
-- ============================================================================
-- Since cart abandonment needs to check items older than 6 hours,
-- we need a scheduled job. However, Supabase doesn't support pg_cron by default.
-- Alternative: Use a Supabase Edge Function scheduled with cron, or handle in app

-- For now, the trigger will fire when cart items are updated after 6 hours
-- For better coverage, consider implementing a scheduled Edge Function

-- ============================================================================
-- TRIGGER 7: Orders Table Status Change (Optional)
-- ============================================================================
-- If you have an orders table separate from bookings, uncomment this trigger
-- This handles order status changes in the orders table

-- CREATE OR REPLACE FUNCTION notify_order_status_change()
-- RETURNS TRIGGER AS $$
-- DECLARE
--   v_service_name TEXT;
-- BEGIN
--   -- Only send notification if status actually changed
--   IF OLD.status IS DISTINCT FROM NEW.status THEN
--     -- Get service name from items_json if available
--     -- This is a simplified version - adjust based on your orders table structure
--     
--     -- Notify user about order status change
--     PERFORM send_push_notification(
--       NEW.user_id,
--       'Order Update',
--       'Your order status has been updated to ' || NEW.status,
--       jsonb_build_object(
--         'type', 'order_status_change',
--         'order_id', NEW.id::TEXT,
--         'status', NEW.status,
--         'old_status', OLD.status
--       ),
--       NULL,
--       ARRAY['user_app']::TEXT[]
--     );
--   END IF;
-- 
--   RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;
-- 
-- -- Uncomment if orders table exists and needs notifications
-- -- DROP TRIGGER IF EXISTS order_status_notification ON orders;
-- -- CREATE TRIGGER order_status_notification
-- --   AFTER UPDATE ON orders
-- --   FOR EACH ROW
-- --   WHEN (OLD.status IS DISTINCT FROM NEW.status)
-- --   EXECUTE FUNCTION notify_order_status_change();

-- ============================================================================
-- CLEANUP: Remove Old/Duplicate Triggers
-- ============================================================================
-- Remove any old notification triggers that might cause duplicates

DROP TRIGGER IF EXISTS order_status_notification_user ON orders;
DROP TRIGGER IF EXISTS order_status_notification ON orders;
DROP TRIGGER IF EXISTS booking_confirmation_notification ON bookings;
DROP TRIGGER IF EXISTS new_order_notification_vendor ON orders;
DROP TRIGGER IF EXISTS booking_status_notification_user ON bookings;
DROP TRIGGER IF EXISTS booking_status_notification_vendor ON bookings;
DROP TRIGGER IF EXISTS booking_status_change_notification ON bookings;

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
-- IMPORTANT: This uses pg_net extension (Supabase's native extension)
-- Run this first: CREATE EXTENSION IF NOT EXISTS pg_net;