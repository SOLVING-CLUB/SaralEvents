-- ============================================================================
-- TEST NOTIFICATION TRIGGERS
-- Run this to verify triggers are working and send_push_notification function exists
-- ============================================================================

-- Step 1: Verify send_push_notification function exists
SELECT 
  'send_push_notification Function' as check_type,
  routine_name,
  routine_type,
  CASE 
    WHEN routine_name = 'send_push_notification' THEN '✅ Function exists'
    ELSE '❌ Function does NOT exist'
  END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'send_push_notification';

-- Step 2: Check environment variables
SELECT 
  'Environment Variables' as check_type,
  CASE 
    WHEN current_setting('app.supabase_url', true) IS NOT NULL 
      AND current_setting('app.supabase_url', true) != ''
    THEN '✅ supabase_url is set'
    ELSE '❌ supabase_url NOT set - Run: ALTER DATABASE postgres SET app.supabase_url = ''...'';'
  END AS supabase_url_status,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
      AND current_setting('app.supabase_service_role_key', true) != ''
    THEN '✅ service_role_key is set'
    ELSE '❌ service_role_key NOT set - Run: ALTER DATABASE postgres SET app.supabase_service_role_key = ''...'';'
  END AS service_role_key_status;

-- Step 3: Get a test user ID with active FCM tokens
SELECT 
  'Test Users with FCM Tokens' as check_type,
  u.id as user_id,
  u.email,
  ft.app_type,
  ft.device_type,
  ft.is_active
FROM auth.users u
JOIN fcm_tokens ft ON ft.user_id = u.id
WHERE ft.is_active = true
ORDER BY ft.updated_at DESC
LIMIT 5;

-- Step 4: Test send_push_notification function
-- Uncomment and replace USER_ID with a user ID from Step 3
/*
SELECT send_push_notification(
  'USER_ID_FROM_STEP_3'::UUID,  -- Replace with actual user ID
  'Test Notification',
  'This is a test to verify notifications are working',
  jsonb_build_object(
    'type', 'test',
    'timestamp', NOW()::TEXT
  ),
  NULL,
  ARRAY['user_app']::TEXT[]
) as test_result;
*/

-- Step 5: Check if triggers are actually firing
-- Check recent bookings that should have triggered notifications
SELECT 
  'Recent Bookings (Should Trigger Notifications)' as check_type,
  b.id,
  b.status,
  b.created_at,
  CASE 
    WHEN b.created_at >= NOW() - INTERVAL '1 hour' THEN '✅ Should have triggered new_booking_notification'
    ELSE '⚠️ Older booking'
  END as notification_expected
FROM bookings b
WHERE b.created_at >= NOW() - INTERVAL '24 hours'
ORDER BY b.created_at DESC
LIMIT 5;

-- Step 6: Check recent payment milestones that should have triggered notifications
SELECT 
  'Recent Payment Milestones (Should Trigger Notifications)' as check_type,
  pm.id,
  pm.milestone_type,
  pm.status,
  pm.amount,
  pm.updated_at,
  CASE 
    WHEN pm.status IN ('paid', 'held_in_escrow', 'released') 
      AND pm.updated_at >= NOW() - INTERVAL '1 hour' 
    THEN '✅ Should have triggered payment_success_notification'
    ELSE '⚠️ Check conditions'
  END as notification_expected
FROM payment_milestones pm
WHERE pm.updated_at >= NOW() - INTERVAL '24 hours'
  OR pm.created_at >= NOW() - INTERVAL '24 hours'
ORDER BY pm.updated_at DESC, pm.created_at DESC
LIMIT 5;

-- Step 7: Verify trigger functions exist
SELECT 
  'Trigger Functions' as check_type,
  routine_name,
  '✅ Exists' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'notify_payment_success',
    'notify_booking_status_change',
    'notify_new_booking'
  )
ORDER BY routine_name;

-- Step 8: Check trigger status (should all be enabled)
SELECT 
  'Trigger Status' as check_type,
  t.trigger_name,
  t.event_object_table,
  t.event_manipulation,
  CASE 
    WHEN pt.tgisinternal THEN '❌ Internal (disabled)'
    WHEN pt.tgenabled = 'O' THEN '✅ Enabled'
    WHEN pt.tgenabled = 'D' THEN '❌ Disabled'
    ELSE '⚠️ Unknown'
  END as trigger_status
FROM information_schema.triggers t
JOIN pg_trigger pt ON pt.tgname = t.trigger_name
WHERE t.trigger_schema = 'public'
  AND t.trigger_name IN (
    'payment_success_notification',
    'booking_status_change_notification',
    'new_booking_notification'
  )
ORDER BY t.event_object_table, t.trigger_name;

-- ============================================================================
-- MANUAL TEST
-- ============================================================================
-- To manually test if send_push_notification works:
-- 1. Get a user ID from Step 3
-- 2. Uncomment and run Step 4 with that user ID
-- 3. Check if you get a response with "success": true
-- 4. Check Supabase Dashboard > Edge Functions > send-push-notification > Logs
