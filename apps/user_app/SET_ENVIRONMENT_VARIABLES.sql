-- ============================================================================
-- SET ENVIRONMENT VARIABLES FOR NOTIFICATIONS
-- IMPORTANT: Replace the values below with your actual Supabase project details
-- ============================================================================

-- Step 1: Get your Supabase Project URL
-- Go to: Supabase Dashboard > Settings > API
-- Copy the "Project URL" (it looks like: https://xxxxx.supabase.co)

-- Step 2: Get your Service Role Key
-- Go to: Supabase Dashboard > Settings > API > Secret keys
-- Click the eye icon next to "default" secret key to reveal it
-- Copy the entire key (it starts with: sb_secret_...)

-- Step 3: Replace the values below and run these commands:

-- Set Supabase URL (replace with your actual project URL)
ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';

-- Set Service Role Key (replace with your actual service role key)
ALTER DATABASE postgres SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY_HERE';

-- Step 4: Verify the settings were applied
SELECT 
  'Verification' as check_type,
  CASE 
    WHEN current_setting('app.supabase_url', true) IS NOT NULL 
    THEN '✅ app.supabase_url is set'
    ELSE '❌ app.supabase_url is NOT set'
  END AS url_status,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
    THEN '✅ app.supabase_service_role_key is set'
    ELSE '❌ app.supabase_service_role_key is NOT set'
  END AS key_status;

-- Step 5: Test the notification function
DO $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT send_push_notification(
    '00000000-0000-0000-0000-000000000000'::UUID,
    'Test Notification',
    'Testing notification system after setting environment variables',
    '{"type":"test"}'::JSONB,
    NULL,
    ARRAY['user_app']::TEXT[]
  ) INTO v_result;
  
  RAISE NOTICE 'Test result: %', v_result;
  
  IF (v_result->>'success')::boolean = true THEN
    RAISE NOTICE '✅ SUCCESS! Notification system is working!';
  ELSIF (v_result->>'skipped')::boolean = true THEN
    RAISE WARNING '⚠️ Notification was skipped. Check the result above for details.';
  ELSE
    RAISE WARNING '⚠️ Notification failed. Check the result above for details.';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '❌ Error: %', SQLERRM;
END $$;
