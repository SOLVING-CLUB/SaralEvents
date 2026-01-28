-- ============================================================================
-- DIAGNOSE PAYMENT AND ORDER NOTIFICATIONS
-- Run this to check why payment and order notifications aren't working
-- ============================================================================

-- Step 1: Check if triggers exist and are active
SELECT 
  'Notification Triggers Status' as check_type,
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation,
  CASE 
    WHEN tgisinternal THEN '❌ Internal (disabled)'
    ELSE '✅ Active'
  END as status
FROM information_schema.triggers t
JOIN pg_trigger pt ON pt.tgname = t.trigger_name
WHERE t.trigger_schema = 'public'
  AND t.trigger_name IN (
    'payment_success_notification',
    'booking_status_change_notification'
  )
ORDER BY event_object_table, trigger_name;

-- Step 2: Check if send_push_notification function exists
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

-- Step 3: Check environment variables
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

-- Step 4: Check recent payment milestones (last 24 hours)
SELECT 
  'Recent Payment Milestones' as check_type,
  pm.id,
  pm.booking_id,
  pm.milestone_type,
  pm.amount,
  pm.status,
  pm.created_at,
  pm.updated_at,
  CASE 
    WHEN pm.status IN ('paid', 'held_in_escrow', 'released') THEN '✅ Should trigger notification'
    ELSE '⚠️ Status not in trigger condition'
  END as notification_status
FROM payment_milestones pm
WHERE pm.created_at >= NOW() - INTERVAL '24 hours'
  OR pm.updated_at >= NOW() - INTERVAL '24 hours'
ORDER BY pm.updated_at DESC, pm.created_at DESC
LIMIT 10;

-- Step 5: Check recent bookings (last 24 hours)
SELECT 
  'Recent Bookings' as check_type,
  b.id,
  b.user_id,
  b.vendor_id,
  b.status,
  b.milestone_status,
  b.created_at,
  b.updated_at,
  CASE 
    WHEN b.status = 'pending' AND b.created_at >= NOW() - INTERVAL '1 hour' THEN '✅ New order - should notify vendor'
    WHEN b.status = 'confirmed' AND b.updated_at >= NOW() - INTERVAL '1 hour' THEN '✅ Status changed - should notify user'
    ELSE '⚠️ Check trigger conditions'
  END as notification_status
FROM bookings b
WHERE b.created_at >= NOW() - INTERVAL '24 hours'
  OR b.updated_at >= NOW() - INTERVAL '24 hours'
ORDER BY b.updated_at DESC, b.created_at DESC
LIMIT 10;

-- Step 6: Check pg_net request queue for errors (last hour)
-- Note: Column structure varies by pg_net version
-- First, check what columns exist
SELECT 
  'pg_net Table Columns' as check_type,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'net' 
  AND table_name = 'http_request_queue'
ORDER BY ordinal_position;

-- Query pg_net request queue (using only id and url which should always exist)
-- Note: Time filtering may not work if timestamp column has different name
SELECT 
  'pg_net Request Queue' as check_type,
  id,
  url
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 20;

-- Note: To check for errors and timestamps, check Supabase Dashboard > Logs > Postgres Logs
-- or use: SELECT * FROM net.http_request_queue LIMIT 5; to see all available columns

-- Step 7: Check for active FCM tokens
SELECT 
  'Active FCM Tokens' as check_type,
  app_type,
  COUNT(*) as token_count,
  COUNT(DISTINCT user_id) as unique_users
FROM fcm_tokens
WHERE is_active = true
GROUP BY app_type;

-- Step 8: Test send_push_notification function manually
-- Uncomment and replace USER_ID with actual user ID to test
/*
SELECT send_push_notification(
  'USER_ID_HERE'::UUID,  -- Replace with actual user ID
  'Test Payment Notification',
  'This is a test to verify notifications are working',
  jsonb_build_object('type', 'test', 'test_time', NOW()::TEXT),
  NULL,
  ARRAY['user_app']::TEXT[]
) as test_result;
*/

-- Step 9: Check if vendor has user_id mapped correctly
SELECT 
  'Vendor User ID Mapping' as check_type,
  vp.id as vendor_profile_id,
  vp.user_id as vendor_user_id,
  COUNT(b.id) as booking_count,
  MAX(b.created_at) as latest_booking
FROM vendor_profiles vp
LEFT JOIN bookings b ON b.vendor_id = vp.id
WHERE b.created_at >= NOW() - INTERVAL '24 hours'
GROUP BY vp.id, vp.user_id
LIMIT 10;

-- Step 10: Check for trigger execution errors in PostgreSQL logs
-- Note: This requires access to PostgreSQL logs
SELECT 
  'Trigger Execution Check' as check_type,
  '⚠️ Manual Check Required' as status,
  'Check Supabase Dashboard > Logs > Postgres Logs for trigger errors' as instruction;

-- ============================================================================
-- QUICK FIXES
-- ============================================================================

-- If triggers don't exist, run this:
/*
-- Recreate payment success trigger
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;
CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
  EXECUTE FUNCTION notify_payment_success();

-- Recreate booking status change trigger
DROP TRIGGER IF EXISTS booking_status_change_notification ON bookings;
CREATE TRIGGER booking_status_change_notification
  AFTER INSERT OR UPDATE ON bookings
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD IS NULL)
  EXECUTE FUNCTION notify_booking_status_change();
*/

-- If send_push_notification function doesn't exist, run:
-- apps/user_app/automated_notification_triggers.sql

-- If environment variables are not set:
/*
ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT.supabase.co';
ALTER DATABASE postgres SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';
*/
