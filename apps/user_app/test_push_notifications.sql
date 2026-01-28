-- ============================================================================
-- TEST PUSH NOTIFICATIONS END-TO-END
-- Run this to test if push notifications are working
-- ============================================================================

-- Step 1: Check if send_push_notification function exists
SELECT 
  'send_push_notification Function' as check_type,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_name = 'send_push_notification'
    )
    THEN '✅ Function exists'
    ELSE '❌ Function does NOT exist - Run automated_notification_triggers.sql'
  END AS status;

-- Step 2: Check environment variables
SELECT 
  'Environment Variables' as check_type,
  CASE 
    WHEN current_setting('app.supabase_url', true) IS NOT NULL 
      AND current_setting('app.supabase_url', true) != ''
    THEN '✅ supabase_url is set'
    ELSE '❌ supabase_url NOT set'
  END AS supabase_url_status,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
      AND current_setting('app.supabase_service_role_key', true) != ''
    THEN '✅ service_role_key is set'
    ELSE '❌ service_role_key NOT set'
  END AS service_role_key_status;

-- Step 3: Check for active tokens
SELECT 
  'Active Tokens' as check_type,
  COUNT(*) as total_active_tokens,
  COUNT(CASE WHEN app_type = 'user_app' THEN 1 END) as user_app_tokens,
  COUNT(CASE WHEN app_type = 'vendor_app' THEN 1 END) as vendor_app_tokens
FROM fcm_tokens
WHERE is_active = true;

-- Step 4: Test send_push_notification function (replace USER_ID with actual user ID)
-- This will test if the function can call the edge function
-- Note: Replace 'YOUR_USER_ID_HERE' with an actual user ID from your database
/*
SELECT send_push_notification(
  'YOUR_USER_ID_HERE'::UUID,  -- Replace with actual user ID
  'Test Notification',
  'This is a test notification to verify push notifications are working',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
) as test_result;
*/

-- Step 5: Check edge function deployment status
-- Note: This requires checking Supabase Dashboard or using Supabase CLI
-- CLI command: supabase functions list
SELECT 
  'Edge Function Check' as check_type,
  '⚠️ Manual Check Required' as status,
  'Run: supabase functions list' as instruction,
  'Or check Supabase Dashboard > Edge Functions' as alternative;

-- Step 6: Check pg_net request queue (recent requests)
SELECT 
  'Recent pg_net Requests' as check_type,
  COUNT(*) as total_requests,
  COUNT(CASE WHEN status = 'SUCCESS' THEN 1 END) as successful,
  COUNT(CASE WHEN status = 'ERROR' THEN 1 END) as failed,
  MAX(created_at) as latest_request
FROM net.http_request_queue
WHERE created_at >= NOW() - INTERVAL '1 hour';

-- Step 7: Check for notification triggers
SELECT 
  'Notification Triggers' as check_type,
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE '%notification%'
ORDER BY event_object_table, trigger_name;

-- Step 8: Get a test user ID (if you want to test)
-- Uncomment and run to get a user ID for testing
/*
SELECT 
  'Test User IDs' as check_type,
  u.id as user_id,
  u.email,
  COUNT(ft.id) as token_count,
  STRING_AGG(DISTINCT ft.app_type, ', ') as app_types
FROM auth.users u
LEFT JOIN fcm_tokens ft ON ft.user_id = u.id AND ft.is_active = true
GROUP BY u.id, u.email
HAVING COUNT(ft.id) > 0
LIMIT 5;
*/

-- ============================================================================
-- MANUAL TESTING INSTRUCTIONS
-- ============================================================================

-- To test push notifications manually:

-- 1. Get a user ID with active tokens:
SELECT 
  u.id as user_id,
  u.email,
  ft.app_type,
  ft.device_type
FROM auth.users u
JOIN fcm_tokens ft ON ft.user_id = u.id
WHERE ft.is_active = true
LIMIT 1;

-- 2. Test the send_push_notification function:
-- Replace USER_ID and EMAIL with values from step 1
/*
SELECT send_push_notification(
  'USER_ID_FROM_STEP_1'::UUID,
  'Test Push Notification',
  'If you receive this, push notifications are working!',
  jsonb_build_object(
    'type', 'test',
    'timestamp', NOW()::TEXT
  ),
  NULL,
  ARRAY['user_app']::TEXT[]  -- or ['vendor_app'] for vendor app
) as result;
*/

-- 3. Check the result:
-- - If success: true, the request was queued
-- - Check edge function logs: supabase functions logs send-push-notification
-- - Check device for notification

-- 4. Check pg_net request queue for errors:
SELECT 
  id,
  url,
  method,
  status,
  error_msg,
  created_at
FROM net.http_request_queue
WHERE created_at >= NOW() - INTERVAL '5 minutes'
ORDER BY created_at DESC
LIMIT 10;
