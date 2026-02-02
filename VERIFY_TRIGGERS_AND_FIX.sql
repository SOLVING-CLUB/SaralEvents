-- ============================================================================
-- VERIFY TRIGGERS AND FIX ORDER FLOW NOTIFICATIONS
-- ============================================================================

-- Step 1: Check if triggers exist
SELECT 
  'Trigger Status' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  CASE 
    WHEN trigger_name IS NOT NULL THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name IN (
    'new_booking_notification',
    'booking_status_change_notification',
    'payment_success_notification',
    'refund_initiated_notification',
    'refund_completed_notification',
    'cart_abandonment_notification',
    'milestone_confirmation_notification_vendor',
    'wallet_payment_released_notification',
    'withdrawal_status_notification'
  )
ORDER BY event_object_table, trigger_name;

-- Step 2: Check if send_push_notification function uses anon key
SELECT 
  'Function Check' as check_type,
  routine_name,
  CASE 
    WHEN routine_definition LIKE '%anon%' OR routine_definition LIKE '%eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9%' THEN '✅ Uses Anon Key'
    WHEN routine_definition LIKE '%service_role%' OR routine_definition LIKE '%sb_secret_QhWTQOnAO%' THEN '⚠️ Uses Service Role Key (needs update)'
    ELSE '❓ Unknown'
  END as key_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'send_push_notification';

-- Step 3: Update send_push_notification to use anon key (if not already updated)
CREATE OR REPLACE FUNCTION send_push_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT NULL,
  p_image_url TEXT DEFAULT NULL,
  p_app_types TEXT[] DEFAULT ARRAY['user_app', 'vendor_app']
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_supabase_url TEXT;
  v_anon_key TEXT;  -- Changed to anon key
  v_request_id BIGINT;
BEGIN
  v_supabase_url := current_setting('app.supabase_url', true);
  v_anon_key := current_setting('app.supabase_anon_key', true);
  
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://hucsihwqsuvqvbnyapdn.supabase.co';
  END IF;
  
  IF v_anon_key IS NULL THEN
    -- Use anon key (works with pg_net to edge functions)
    v_anon_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1Y3NpaHdxc3V2cXZibnlhcGRuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk0ODYsImV4cCI6MjA2ODA1NTQ4Nn0.gSu1HE7eZ4n3biaM338wDF0L2m4Yc3xYyt2GtuPOr1w';
  END IF;

  BEGIN
    v_request_id := net.http_post(
      url := v_supabase_url || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_anon_key,  -- Using anon key
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
    WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;

-- Step 4: Verify new_booking_notification trigger exists (for new orders)
SELECT 
  'New Booking Trigger' as check_type,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.triggers 
      WHERE trigger_name = 'new_booking_notification' 
      AND event_object_table = 'bookings'
    ) THEN '✅ EXISTS'
    ELSE '❌ MISSING - Need to create'
  END as status;

-- Step 5: Create new_booking_notification trigger if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers 
    WHERE trigger_name = 'new_booking_notification' 
    AND event_object_table = 'bookings'
  ) THEN
    -- Create notify_new_booking function
    CREATE OR REPLACE FUNCTION notify_new_booking()
    RETURNS TRIGGER AS $$
    DECLARE
      v_service_name TEXT;
      v_vendor_user_id UUID;
    BEGIN
      -- Get service name
      SELECT name INTO v_service_name
      FROM services
      WHERE id = NEW.service_id;

      -- Get vendor's user_id
      SELECT user_id INTO v_vendor_user_id
      FROM vendor_profiles
      WHERE id = NEW.vendor_id;

      -- Notify vendor about new order
      IF v_vendor_user_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_vendor_user_id,
          'New Order Received',
          COALESCE(
            'You have a new order for ' || v_service_name || '. Please review and confirm.',
            'You have a new order. Please review and confirm.'
          ),
          jsonb_build_object(
            'type', 'new_booking',
            'booking_id', NEW.id::TEXT,
            'service_id', NEW.service_id::TEXT,
            'user_id', NEW.user_id::TEXT
          ),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
      END IF;

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    -- Create trigger
    CREATE TRIGGER new_booking_notification
      AFTER INSERT ON bookings
      FOR EACH ROW
      EXECUTE FUNCTION notify_new_booking();
    
    RAISE NOTICE '✅ Created new_booking_notification trigger';
  ELSE
    RAISE NOTICE '✅ new_booking_notification trigger already exists';
  END IF;
END $$;

-- Step 6: Final verification - List all notification triggers
SELECT 
  'All Notification Triggers' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE '%notification%'
ORDER BY event_object_table, trigger_name;
