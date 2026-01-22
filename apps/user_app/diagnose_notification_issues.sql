-- ============================================================================
-- NOTIFICATION SYSTEM DIAGNOSTICS
-- Run this to check all potential issues with notifications
-- ============================================================================

-- 1. Check if pg_net extension is enabled
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
    THEN '✅ pg_net extension is enabled'
    ELSE '❌ pg_net extension is NOT enabled. Run: CREATE EXTENSION IF NOT EXISTS pg_net;'
  END AS pg_net_status;

-- 2. Check if environment variables are set
SELECT 
  CASE 
    WHEN current_setting('app.supabase_url', true) IS NOT NULL 
    THEN '✅ app.supabase_url is set'
    ELSE '❌ app.supabase_url is NOT set. Run: ALTER DATABASE postgres SET app.supabase_url = ''https://your-project.supabase.co'';'
  END AS supabase_url_status,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
    THEN '✅ app.supabase_service_role_key is set'
    ELSE '❌ app.supabase_service_role_key is NOT set. Run: ALTER DATABASE postgres SET app.supabase_service_role_key = ''your-service-role-key'';'
  END AS service_role_key_status;

-- 3. Check if fcm_tokens table has app_type column
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'fcm_tokens' AND column_name = 'app_type'
    )
    THEN '✅ app_type column exists'
    ELSE '❌ app_type column does NOT exist. Run: ALTER TABLE fcm_tokens ADD COLUMN app_type TEXT CHECK (app_type IN (''user_app'',''vendor_app'',''company_web'')) DEFAULT ''user_app'';'
  END AS app_type_column_status;

-- 4. Check if triggers exist
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor',
  'refund_initiated_notification',
  'refund_completed_notification'
)
ORDER BY trigger_name;

-- 5. Check if functions exist
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_name IN (
  'send_push_notification',
  'notify_booking_status_change',
  'notify_payment_success',
  'notify_vendor_milestone_confirmations',
  'notify_refund_initiated',
  'notify_refund_completed'
)
ORDER BY routine_name;

-- 6. Check FCM tokens registration
SELECT 
  COUNT(*) as total_tokens,
  COUNT(CASE WHEN app_type = 'user_app' THEN 1 END) as user_app_tokens,
  COUNT(CASE WHEN app_type = 'vendor_app' THEN 1 END) as vendor_app_tokens,
  COUNT(CASE WHEN app_type IS NULL THEN 1 END) as null_app_type_tokens,
  COUNT(CASE WHEN is_active = true THEN 1 END) as active_tokens
FROM fcm_tokens;

-- 7. Check recent FCM tokens (last 7 days)
SELECT 
  user_id,
  app_type,
  device_type,
  is_active,
  created_at,
  updated_at
FROM fcm_tokens
WHERE created_at >= NOW() - INTERVAL '7 days'
ORDER BY created_at DESC
LIMIT 10;

-- 8. Check if send_push_notification function can be called (test with dummy data)
-- This will show if the function exists and can be executed
DO $$
DECLARE
  v_result JSONB;
BEGIN
  -- Try to call the function (it will fail silently if config is missing, but function exists)
  SELECT send_push_notification(
    '00000000-0000-0000-0000-000000000000'::UUID,
    'Test',
    'Test notification',
    '{}'::JSONB,
    NULL,
    ARRAY['user_app']::TEXT[]
  ) INTO v_result;
  
  RAISE NOTICE 'Function call result: %', v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Function error: %', SQLERRM;
END $$;

-- 9. Check recent booking status changes (to see if triggers are firing)
SELECT 
  id,
  status,
  milestone_status,
  user_id,
  vendor_id,
  updated_at
FROM bookings
WHERE updated_at >= NOW() - INTERVAL '24 hours'
ORDER BY updated_at DESC
LIMIT 10;

-- 10. Check recent payment milestones (to see if triggers are firing)
SELECT 
  id,
  booking_id,
  milestone_type,
  status,
  amount,
  created_at,
  updated_at
FROM payment_milestones
WHERE created_at >= NOW() - INTERVAL '24 hours' 
   OR updated_at >= NOW() - INTERVAL '24 hours'
ORDER BY COALESCE(updated_at, created_at) DESC
LIMIT 10;

-- 11. Check pg_net request history (if available)
-- This shows if the Edge Function is being called
-- Note: Column names may vary depending on pg_net version
DO $$
BEGIN
  -- Try to query the table (will fail silently if columns don't exist)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'net' AND table_name = 'http_request_queue') THEN
    RAISE NOTICE '✅ net.http_request_queue table exists';
    -- Try to get column names
    PERFORM 1 FROM net.http_request_queue LIMIT 1;
    RAISE NOTICE '✅ Can query net.http_request_queue table';
  ELSE
    RAISE NOTICE '⚠️ net.http_request_queue table does not exist (this is normal if no requests have been made)';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Cannot query net.http_request_queue: %', SQLERRM;
END $$;

-- 12. Summary of issues
SELECT 
  'DIAGNOSTIC SUMMARY' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
      AND current_setting('app.supabase_url', true) IS NOT NULL
      AND current_setting('app.supabase_service_role_key', true) IS NOT NULL
      AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fcm_tokens' AND column_name = 'app_type')
    THEN '✅ All critical components are configured'
    ELSE '❌ Some critical components are missing - check above for details'
  END AS overall_status;
