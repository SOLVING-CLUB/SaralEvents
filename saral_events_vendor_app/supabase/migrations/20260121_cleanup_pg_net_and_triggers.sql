-- Purpose:
-- 1) Stop errors: "type http_response does not exist" (http extension not enabled)
-- 2) Avoid duplicate trigger/policy errors when scripts are re-run
-- 3) Ensure notification helper uses pg_net (async) and skips safely if config/extension missing

-- Enable pg_net if available
CREATE EXTENSION IF NOT EXISTS pg_net;

-- -----------------------------------------------------------------------------
-- Replace send_push_notification to avoid http_response dependency
-- -----------------------------------------------------------------------------
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
  -- Safe reads: missing_ok=true prevents 42704
  v_supabase_url := current_setting('app.supabase_url', true);
  v_service_role_key := current_setting('app.supabase_service_role_key', true);

  IF v_supabase_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE WARNING 'Push notifications skipped: missing app.supabase_url or app.supabase_service_role_key';
    RETURN jsonb_build_object(
      'success', false,
      'skipped', true,
      'reason', 'missing_config'
    );
  END IF;

  -- Prefer pg_net (async). If not available, skip gracefully.
  BEGIN
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

    RETURN jsonb_build_object(
      'success', true,
      'request_id', v_request_id,
      'message', 'Notification request queued'
    );
  EXCEPTION
    WHEN undefined_function OR invalid_schema_name OR undefined_table THEN
      RAISE WARNING 'Push notifications skipped: pg_net not available';
      RETURN jsonb_build_object(
        'success', false,
        'skipped', true,
        'reason', 'pg_net_not_available'
      );
  END;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- -----------------------------------------------------------------------------
-- Clean up trigger duplicates: booking_status_change_notification on bookings
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE t.tgname = 'booking_status_change_notification'
      AND c.relname = 'bookings'
  ) THEN
    EXECUTE 'DROP TRIGGER booking_status_change_notification ON bookings';
  END IF;
END;
$$;

-- Recreate trigger guarded on status change (only if function exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE t.tgname = 'booking_status_change_notification'
      AND c.relname = 'bookings'
  ) THEN
    EXECUTE '
      CREATE TRIGGER booking_status_change_notification
      AFTER UPDATE ON bookings
      FOR EACH ROW
      WHEN (OLD.status IS DISTINCT FROM NEW.status)
      EXECUTE FUNCTION notify_booking_status_change()
    ';
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- Avoid duplicate policy errors: refunds "Users can view their refunds"
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = current_schema()
      AND tablename = 'refunds'
      AND policyname = 'Users can view their refunds'
  ) THEN
    EXECUTE '
      CREATE POLICY "Users can view their refunds" ON refunds
        FOR SELECT USING (
          EXISTS (
            SELECT 1 FROM bookings b
            WHERE b.id = refunds.booking_id
              AND b.user_id = auth.uid()
          )
        )
    ';
  END IF;
END;
$$;

