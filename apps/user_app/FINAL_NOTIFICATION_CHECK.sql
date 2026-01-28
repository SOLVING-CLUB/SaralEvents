-- ============================================================================
-- FINAL CHECK: Why Notifications Aren't Working
-- Run this to identify the exact issue
-- ============================================================================

-- ============================================================================
-- STEP 1: Check if send_push_notification function exists
-- ============================================================================
SELECT 
  'STEP 1: Function Exists?' as check,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_schema = 'public' 
      AND routine_name = 'send_push_notification'
    )
    THEN '✅ YES - Function exists'
    ELSE '❌ NO - Run: automated_notification_triggers.sql (lines 24-112)'
  END as result;

-- ============================================================================
-- STEP 2: Check if pg_net extension is enabled
-- ============================================================================
SELECT 
  'STEP 2: pg_net Enabled?' as check,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
    THEN '✅ YES - pg_net is enabled'
    ELSE '❌ NO - Run: CREATE EXTENSION IF NOT EXISTS pg_net;'
  END as result;

-- ============================================================================
-- STEP 3: Check environment variables (optional - function has fallbacks)
-- ============================================================================
SELECT 
  'STEP 3: Environment Variables' as check,
  CASE 
    WHEN current_setting('app.supabase_url', true) IS NOT NULL 
      AND current_setting('app.supabase_url', true) != ''
    THEN '✅ supabase_url is SET'
    ELSE '⚠️ NOT SET (but function has hardcoded fallback)'
  END AS supabase_url,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
      AND current_setting('app.supabase_service_role_key', true) != ''
    THEN '✅ service_role_key is SET'
    ELSE '⚠️ NOT SET (but function has hardcoded fallback)'
  END AS service_role_key;

-- ============================================================================
-- STEP 4: Check if users have FCM tokens
-- ============================================================================
SELECT 
  'STEP 4: FCM Tokens' as check,
  COUNT(*) as total_tokens,
  COUNT(DISTINCT user_id) as unique_users,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Users have tokens'
    ELSE '❌ NO TOKENS - Users need to login to apps to register tokens'
  END as result
FROM fcm_tokens
WHERE is_active = true;

-- ============================================================================
-- STEP 5: Test send_push_notification function
-- ============================================================================
-- First, get a user ID to test with
SELECT 
  'STEP 5: Test User' as check,
  u.id::TEXT as user_id,
  u.email,
  ft.app_type,
  'Use this user_id in the test below' as instruction
FROM auth.users u
JOIN fcm_tokens ft ON ft.user_id = u.id
WHERE ft.is_active = true
LIMIT 1;

-- ============================================================================
-- STEP 6: Manual Test (Uncomment and replace USER_ID)
-- ============================================================================
/*
SELECT send_push_notification(
  'PASTE_USER_ID_FROM_STEP_5'::UUID,
  'Test Notification',
  'If you see this, the function works!',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
) as test_result;
*/

-- ============================================================================
-- STEP 7: Check recent bookings/payments that should have triggered
-- ============================================================================
SELECT 
  'STEP 7: Recent Bookings' as check,
  COUNT(*) as recent_bookings,
  'Check if any bookings were created in last hour' as note
FROM bookings
WHERE created_at >= NOW() - INTERVAL '1 hour';

SELECT 
  'STEP 7: Recent Payments' as check,
  COUNT(*) as recent_payments,
  'Check if any payments were made in last hour' as note
FROM payment_milestones
WHERE (created_at >= NOW() - INTERVAL '1 hour' OR updated_at >= NOW() - INTERVAL '1 hour')
  AND status IN ('paid', 'held_in_escrow', 'released');

-- ============================================================================
-- SUMMARY & ACTION ITEMS
-- ============================================================================
SELECT 
  '=== ACTION ITEMS ===' as summary,
  CASE 
    WHEN NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name = 'send_push_notification')
    THEN '1. ❌ Run automated_notification_triggers.sql to create send_push_notification function'
    WHEN NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
    THEN '2. ❌ Run: CREATE EXTENSION IF NOT EXISTS pg_net;'
    WHEN NOT EXISTS (SELECT 1 FROM fcm_tokens WHERE is_active = true)
    THEN '3. ❌ Users need to login to apps to register FCM tokens'
    WHEN NOT EXISTS (SELECT 1 FROM bookings WHERE created_at >= NOW() - INTERVAL '1 hour')
      AND NOT EXISTS (SELECT 1 FROM payment_milestones WHERE (created_at >= NOW() - INTERVAL '1 hour' OR updated_at >= NOW() - INTERVAL '1 hour') AND status IN ('paid', 'held_in_escrow', 'released'))
    THEN '4. ⚠️ No recent bookings/payments - Test manually with Step 6'
    ELSE '✅ All checks passed! Test the function manually (Step 6) or create a booking/payment to test triggers'
  END as action;
