-- Database Functions and Triggers for Automatic Push Notifications
-- This file contains SQL functions and triggers to automatically send push notifications
-- when certain events occur in the database.

-- ============================================================================
-- HELPER FUNCTION: Send Push Notification via Edge Function
-- ============================================================================
-- This function calls the Supabase Edge Function to send push notifications
-- Note: Requires the http extension to be enabled in Supabase

CREATE OR REPLACE FUNCTION send_push_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT '{}'::JSONB,
  p_image_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_response JSONB;
  v_supabase_url TEXT;
  v_service_role_key TEXT;
  v_http_response http_response;
BEGIN
  -- Get Supabase URL and Service Role Key from environment
  -- These should be set in your Supabase project settings
  v_supabase_url := current_setting('app.supabase_url', true);
  v_service_role_key := current_setting('app.supabase_service_role_key', true);

  -- If not set, try to get from Supabase environment variables
  IF v_supabase_url IS NULL THEN
    v_supabase_url := current_setting('app.supabase_url');
  END IF;

  IF v_service_role_key IS NULL THEN
    v_service_role_key := current_setting('app.supabase_service_role_key');
  END IF;

  -- Call the Edge Function
  SELECT * INTO v_http_response
  FROM http((
    'POST',
    v_supabase_url || '/functions/v1/send-push-notification',
    ARRAY[
      http_header('Authorization', 'Bearer ' || v_service_role_key),
      http_header('Content-Type', 'application/json')
    ],
    'application/json',
    json_build_object(
      'userId', p_user_id,
      'title', p_title,
      'body', p_body,
      'data', p_data,
      'imageUrl', p_image_url
    )::TEXT
  )::http_request);

  -- Parse and return response
  RETURN v_http_response.content::JSONB;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
    RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- ============================================================================
-- TRIGGER: Order Status Update Notification
-- ============================================================================
-- Sends a notification when an order status changes

CREATE OR REPLACE FUNCTION notify_order_status_update()
RETURNS TRIGGER AS $$
DECLARE
  v_service_name TEXT;
BEGIN
  -- Only send notification if status actually changed
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    -- Get service name for better notification message
    SELECT name INTO v_service_name
    FROM services
    WHERE id = NEW.service_id;

    -- Send notification
    PERFORM send_push_notification(
      NEW.user_id,
      'Order Update',
      COALESCE(
        'Your order for ' || COALESCE(v_service_name, 'service') || ' status has been updated to ' || NEW.status,
        'Your order status has been updated to ' || NEW.status
      ),
      jsonb_build_object(
        'type', 'order_update',
        'order_id', NEW.id::TEXT,
        'status', NEW.status,
        'service_id', NEW.service_id::TEXT
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on orders table
DROP TRIGGER IF EXISTS order_status_notification ON orders;
CREATE TRIGGER order_status_notification
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_order_status_update();

-- ============================================================================
-- TRIGGER: Booking Confirmation Notification
-- ============================================================================
-- Sends a notification when a booking is confirmed

CREATE OR REPLACE FUNCTION notify_booking_confirmation()
RETURNS TRIGGER AS $$
DECLARE
  v_service_name TEXT;
BEGIN
  -- Only send notification for new confirmed bookings
  IF NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status != 'confirmed') THEN
    -- Get service name
    SELECT name INTO v_service_name
    FROM services
    WHERE id = NEW.service_id;

    -- Send notification
    PERFORM send_push_notification(
      NEW.user_id,
      'Booking Confirmed',
      COALESCE(
        'Your booking for ' || COALESCE(v_service_name, 'service') || ' has been confirmed',
        'Your booking has been confirmed'
      ),
      jsonb_build_object(
        'type', 'booking_confirmation',
        'booking_id', NEW.id::TEXT,
        'service_id', NEW.service_id::TEXT,
        'booking_date', NEW.booking_date::TEXT
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on bookings table (if exists)
-- DROP TRIGGER IF EXISTS booking_confirmation_notification ON bookings;
-- CREATE TRIGGER booking_confirmation_notification
--   AFTER INSERT OR UPDATE ON bookings
--   FOR EACH ROW
--   WHEN (NEW.status = 'confirmed')
--   EXECUTE FUNCTION notify_booking_confirmation();

-- ============================================================================
-- TRIGGER: Payment Success Notification
-- ============================================================================
-- Sends a notification when payment is successful

CREATE OR REPLACE FUNCTION notify_payment_success()
RETURNS TRIGGER AS $$
BEGIN
  -- Only send notification for successful payments
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    -- Send notification
    PERFORM send_push_notification(
      NEW.user_id,
      'Payment Successful',
      'Your payment of ₹' || NEW.amount::TEXT || ' has been processed successfully',
      jsonb_build_object(
        'type', 'payment',
        'order_id', NEW.order_id::TEXT,
        'amount', NEW.amount::TEXT,
        'success', 'true'
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on payments table (if exists)
-- DROP TRIGGER IF EXISTS payment_success_notification ON payments;
-- CREATE TRIGGER payment_success_notification
--   AFTER INSERT OR UPDATE ON payments
--   FOR EACH ROW
--   WHEN (NEW.status = 'completed')
--   EXECUTE FUNCTION notify_payment_success();

-- ============================================================================
-- TRIGGER: Support Ticket Response Notification
-- ============================================================================
-- Sends a notification when a support ticket receives a response

CREATE OR REPLACE FUNCTION notify_support_response()
RETURNS TRIGGER AS $$
BEGIN
  -- Only send notification if it's a response (not the initial ticket)
  IF NEW.is_from_support = true AND OLD.is_from_support = false THEN
    -- Send notification
    PERFORM send_push_notification(
      NEW.user_id,
      'New Support Response',
      'You have a new response to your support ticket',
      jsonb_build_object(
        'type', 'support',
        'ticket_id', NEW.ticket_id::TEXT,
        'message_id', NEW.id::TEXT
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on support_messages table (if exists)
-- DROP TRIGGER IF EXISTS support_response_notification ON support_messages;
-- CREATE TRIGGER support_response_notification
--   AFTER INSERT ON support_messages
--   FOR EACH ROW
--   WHEN (NEW.is_from_support = true)
--   EXECUTE FUNCTION notify_support_response();

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. Enable the http extension in Supabase:
--    - Go to Database → Extensions
--    - Enable "http" extension
--
-- 2. Set environment variables in Supabase:
--    - Go to Project Settings → Edge Functions → Secrets
--    - Or set via SQL:
--      ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
--      ALTER DATABASE postgres SET app.supabase_service_role_key = 'your-service-role-key';
--
-- 3. Uncomment the triggers you want to use based on your schema
--
-- 4. Test the function manually:
--    SELECT send_push_notification(
--      'user-uuid-here',
--      'Test Notification',
--      'This is a test',
--      '{"type": "test"}'::JSONB
--    );
