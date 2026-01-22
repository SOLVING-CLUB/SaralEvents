-- ============================================================================
-- UPDATE NOTIFICATION CONFIGURATION
-- Since ALTER DATABASE requires superuser (not available in Supabase),
-- we need to update the function with hardcoded values
-- ============================================================================

-- IMPORTANT: Replace the values below with your actual Supabase project details
-- Get these from: Supabase Dashboard > Settings > API

-- Your Supabase Project URL (from Dashboard > Settings > API > Project URL)
-- Example: https://hucsihwqsuvqvbnyapdn.supabase.co
-- Replace 'hucsihwqsuvqvbnyapdn' with your actual project reference

-- Your Service Role Key (from Dashboard > Settings > API > Secret keys)
-- Click the eye icon to reveal it, then copy the full key
-- Example: sb_secret_QhWTQOnAO-SCeCWmWEQF6A_AAdf38pq
-- Replace with your actual service role key

-- The function will be updated automatically when you run automated_notification_triggers.sql
-- But you need to manually edit the function to add your values

-- Step 1: Open apps/user_app/automated_notification_triggers.sql
-- Step 2: Find the send_push_notification function (around line 24)
-- Step 3: Update these two lines with your actual values:
--   v_supabase_url := 'https://YOUR_PROJECT_REF.supabase.co';
--   v_service_role_key := 'YOUR_SERVICE_ROLE_KEY';
-- Step 4: Run the updated automated_notification_triggers.sql file

-- Alternative: Run this to update just the function with your values
-- (Replace the values in the function below)

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
  -- HARDCODED VALUES - Already set with your project values
  -- Your Supabase Project URL
  v_supabase_url := 'https://hucsihwqsuvqvbnyapdn.supabase.co';
  
  -- Your Service Role Key (from Secret keys section)
  v_service_role_key := 'sb_secret_QhWTQOnAO-SCeCWmWEQF6A_AAdf38pq';

  -- Validate we have both values
  IF v_supabase_url IS NULL OR v_service_role_key IS NULL OR 
     v_supabase_url = '' OR v_service_role_key = '' THEN
    RAISE WARNING 'Push notifications skipped: Supabase URL or Service Role Key not configured';
    RETURN jsonb_build_object(
      'success', false,
      'skipped', true,
      'reason', 'missing_config',
      'error', 'Please update send_push_notification function with your Supabase URL and service role key'
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

-- Test the function
DO $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT send_push_notification(
    '00000000-0000-0000-0000-000000000000'::UUID,
    'Test Notification',
    'Testing notification system',
    '{"type":"test"}'::JSONB,
    NULL,
    ARRAY['user_app']::TEXT[]
  ) INTO v_result;
  
  RAISE NOTICE 'Test result: %', v_result;
  
  IF (v_result->>'success')::boolean = true THEN
    RAISE NOTICE '✅ SUCCESS! Notification system is configured correctly!';
  ELSE
    RAISE WARNING '⚠️ Configuration issue: %', v_result;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '❌ Error: %', SQLERRM;
END $$;
