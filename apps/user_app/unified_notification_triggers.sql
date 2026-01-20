-- Unified Notification Triggers for All Applications
-- These triggers send notifications to users, vendors, and company admins
-- based on events like orders, payments, bookings, etc.

-- ============================================================================
-- HELPER FUNCTION: Send Push Notification via Edge Function
-- ============================================================================
-- This function calls the Supabase Edge Function to send push notifications
-- Supports both user_app, vendor_app, and company_web

CREATE OR REPLACE FUNCTION send_push_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT '{}'::JSONB,
  p_image_url TEXT DEFAULT NULL,
  p_app_types TEXT[] DEFAULT ARRAY['user_app', 'vendor_app', 'company_web']::TEXT[]
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
  v_supabase_url := current_setting('app.supabase_url', true);
  v_service_role_key := current_setting('app.supabase_service_role_key', true);

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
      'imageUrl', p_image_url,
      'appTypes', p_app_types
    )::TEXT
  )::http_request);

  RETURN v_http_response.content::JSONB;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
    RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- ============================================================================
-- TRIGGER: Order Status Update - Notify User
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_user_order_update()
RETURNS TRIGGER AS $$
DECLARE
  v_service_name TEXT;
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    -- Get service name
    SELECT name INTO v_service_name
    FROM services
    WHERE id = NEW.service_id;

    -- Notify user
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
      ),
      NULL,
      ARRAY['user_app']::TEXT[]
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS order_status_notification_user ON orders;
CREATE TRIGGER order_status_notification_user
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_user_order_update();

-- ============================================================================
-- TRIGGER: New Order - Notify Vendor
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_vendor_new_order()
RETURNS TRIGGER AS $$
DECLARE
  v_vendor_id UUID;
  v_service_name TEXT;
BEGIN
  -- Get vendor ID from service
  SELECT vendor_id INTO v_vendor_id
  FROM services
  WHERE id = NEW.service_id;

  IF v_vendor_id IS NOT NULL THEN
    -- Get service name
    SELECT name INTO v_service_name
    FROM services
    WHERE id = NEW.service_id;

    -- Notify vendor
    PERFORM send_push_notification(
      v_vendor_id,
      'New Order Received',
      COALESCE(
        'You have a new order for ' || COALESCE(v_service_name, 'service'),
        'You have a new order'
      ),
      jsonb_build_object(
        'type', 'new_order',
        'order_id', NEW.id::TEXT,
        'service_id', NEW.service_id::TEXT,
        'status', NEW.status
      ),
      NULL,
      ARRAY['vendor_app']::TEXT[]
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS new_order_notification_vendor ON orders;
CREATE TRIGGER new_order_notification_vendor
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_vendor_new_order();

-- ============================================================================
-- TRIGGER: Payment Success - Notify User and Vendor
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_payment_success()
RETURNS TRIGGER AS $$
DECLARE
  v_order RECORD;
  v_vendor_id UUID;
BEGIN
  -- Only notify on successful payment
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    -- Get order details
    SELECT * INTO v_order
    FROM orders
    WHERE id = NEW.order_id;

    IF v_order IS NOT NULL THEN
      -- Notify user
      PERFORM send_push_notification(
        v_order.user_id,
        'Payment Successful',
        'Your payment of ₹' || NEW.amount::TEXT || ' has been processed successfully',
        jsonb_build_object(
          'type', 'payment',
          'order_id', NEW.order_id::TEXT,
          'amount', NEW.amount::TEXT,
          'success', 'true'
        ),
        NULL,
        ARRAY['user_app']::TEXT[]
      );

      -- Get vendor ID and notify vendor
      SELECT vendor_id INTO v_vendor_id
      FROM services
      WHERE id = v_order.service_id;

      IF v_vendor_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_vendor_id,
          'Payment Received',
          'Payment of ₹' || NEW.amount::TEXT || ' received for order #' || NEW.order_id::TEXT,
          jsonb_build_object(
            'type', 'payment_received',
            'order_id', NEW.order_id::TEXT,
            'amount', NEW.amount::TEXT
          ),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
      END IF;

      -- Notify company admins (if you have a company_users table)
      -- PERFORM send_push_notification(
      --   'company-admin-user-id',
      --   'New Payment',
      --   'Payment of ₹' || NEW.amount::TEXT || ' received',
      --   jsonb_build_object('type', 'payment', 'order_id', NEW.order_id::TEXT),
      --   NULL,
      --   ARRAY['company_web']::TEXT[]
      -- );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on payments table (adjust table name if different)
-- DROP TRIGGER IF EXISTS payment_success_notification ON payments;
-- CREATE TRIGGER payment_success_notification
--   AFTER INSERT OR UPDATE ON payments
--   FOR EACH ROW
--   WHEN (NEW.status = 'completed')
--   EXECUTE FUNCTION notify_payment_success();

-- ============================================================================
-- TRIGGER: Booking Confirmation - Notify User and Vendor
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_booking_confirmation()
RETURNS TRIGGER AS $$
DECLARE
  v_service_name TEXT;
  v_vendor_id UUID;
BEGIN
  IF NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status != 'confirmed') THEN
    -- Get service details
    SELECT name, vendor_id INTO v_service_name, v_vendor_id
    FROM services
    WHERE id = NEW.service_id;

    -- Notify user
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
      ),
      NULL,
      ARRAY['user_app']::TEXT[]
    );

    -- Notify vendor
    IF v_vendor_id IS NOT NULL THEN
      PERFORM send_push_notification(
        v_vendor_id,
        'New Booking Confirmed',
        COALESCE(
          'New booking confirmed for ' || COALESCE(v_service_name, 'service'),
          'New booking confirmed'
        ),
        jsonb_build_object(
          'type', 'booking_request',
          'booking_id', NEW.id::TEXT,
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

-- Create trigger on bookings table (adjust table name if different)
-- DROP TRIGGER IF EXISTS booking_confirmation_notification ON bookings;
-- CREATE TRIGGER booking_confirmation_notification
--   AFTER INSERT OR UPDATE ON bookings
--   FOR EACH ROW
--   WHEN (NEW.status = 'confirmed')
--   EXECUTE FUNCTION notify_booking_confirmation();

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. Enable the http extension in Supabase:
--    - Go to Database → Extensions → Enable "http"
--
-- 2. Set environment variables:
--    ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
--    ALTER DATABASE postgres SET app.supabase_service_role_key = 'your-service-role-key';
--
-- 3. Adjust table names (orders, payments, bookings) to match your schema
--
-- 4. Uncomment triggers for tables that exist in your schema
--
-- 5. Test triggers manually:
--    SELECT send_push_notification(
--      'user-uuid',
--      'Test',
--      'Test notification',
--      '{"type": "test"}'::JSONB,
--      NULL,
--      ARRAY['user_app', 'vendor_app']::TEXT[]
--    );
