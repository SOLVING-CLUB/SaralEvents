-- ============================================================================
-- QUICK CHECK: Why Notifications Aren't Working
-- Run this to quickly identify the issue
-- ============================================================================

-- Check 1: Does send_push_notification function exist?
SELECT 
  'Function Check' as check_type,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_schema = 'public' 
      AND routine_name = 'send_push_notification'
    )
    THEN '✅ send_push_notification function EXISTS'
    ELSE '❌ send_push_notification function DOES NOT EXIST - Run automated_notification_triggers.sql'
  END as status;

-- Check 2: Are environment variables set?
SELECT 
  'Environment Variables' as check_type,
  CASE 
    WHEN current_setting('app.supabase_url', true) IS NOT NULL 
      AND current_setting('app.supabase_url', true) != ''
    THEN '✅ supabase_url is SET'
    ELSE '❌ supabase_url NOT SET - Run: ALTER DATABASE postgres SET app.supabase_url = ''...'';'
  END AS supabase_url_status,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
      AND current_setting('app.supabase_service_role_key', true) != ''
    THEN '✅ service_role_key is SET'
    ELSE '❌ service_role_key NOT SET - Run: ALTER DATABASE postgres SET app.supabase_service_role_key = ''...'';'
  END AS service_role_key_status;

-- Check 3: Do trigger functions exist?
SELECT 
  'Trigger Functions' as check_type,
  routine_name,
  CASE 
    WHEN routine_name IN ('notify_payment_success', 'notify_booking_status_change', 'notify_new_booking')
    THEN '✅ Exists'
    ELSE '❌ Missing'
  END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'notify_payment_success',
    'notify_booking_status_change',
    'notify_new_booking',
    'send_push_notification'
  )
ORDER BY 
  CASE routine_name
    WHEN 'send_push_notification' THEN 1
    WHEN 'notify_payment_success' THEN 2
    WHEN 'notify_booking_status_change' THEN 3
    WHEN 'notify_new_booking' THEN 4
  END;

-- Check 4: Do users have FCM tokens?
SELECT 
  'FCM Tokens' as check_type,
  app_type,
  COUNT(*) as token_count,
  COUNT(DISTINCT user_id) as unique_users,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Users have tokens'
    ELSE '❌ No FCM tokens registered - Users need to login to apps'
  END as status
FROM fcm_tokens
WHERE is_active = true
GROUP BY app_type;

-- ============================================================================
-- SUMMARY
-- ============================================================================
SELECT 
  '=== SUMMARY ===' as summary,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name = 'send_push_notification')
      AND current_setting('app.supabase_url', true) IS NOT NULL
      AND current_setting('app.supabase_service_role_key', true) IS NOT NULL
      AND EXISTS (SELECT 1 FROM fcm_tokens WHERE is_active = true)
    THEN '✅ Everything looks good! Test the function manually (see below)'
    ELSE '❌ Some components are missing - Fix the issues above'
  END AS overall_status;

-- ============================================================================
-- MANUAL TEST
-- ============================================================================
-- To test if send_push_notification works:
-- 1. Get a user ID:
SELECT 
  'Test User' as info,
  u.id as user_id,
  u.email,
  ft.app_type
FROM auth.users u
JOIN fcm_tokens ft ON ft.user_id = u.id
WHERE ft.is_active = true
LIMIT 1;

-- 2. Test the function (uncomment and replace USER_ID):
/*
SELECT send_push_notification(
  'USER_ID_FROM_ABOVE'::UUID,
  'Test Notification',
  'Testing if notifications work',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
*/

-- 3. Check the result:
-- - If success: true → Function works! Check edge function logs
-- - If error → Check the error message
-- - If NULL or no response → Function might not exist or has errors
