-- ============================================================================
-- COMPLETE NOTIFICATION FIX
-- Run this to fix all notification issues
-- ============================================================================

-- Step 1: Set Environment Variables (Optional but Recommended)
-- Get these from: Supabase Dashboard > Settings > API
-- Replace with your actual values:

/*
ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';
ALTER DATABASE postgres SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';
*/

-- Step 2: Verify send_push_notification function exists
-- If it doesn't exist, the triggers won't work
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_schema = 'public' 
    AND routine_name = 'send_push_notification'
  ) THEN
    RAISE EXCEPTION 'send_push_notification function does NOT exist. Run automated_notification_triggers.sql first!';
  ELSE
    RAISE NOTICE '✅ send_push_notification function exists';
  END IF;
END $$;

-- Step 3: Verify all trigger functions exist
SELECT 
  'Trigger Functions Check' as check_type,
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
ORDER BY routine_name;

-- Step 4: Verify all triggers are enabled
SELECT 
  'Triggers Status' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  '✅ Enabled' as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name IN (
    'payment_success_notification',
    'booking_status_change_notification',
    'new_booking_notification'
  )
ORDER BY event_object_table, trigger_name;

-- Step 5: Check FCM tokens
SELECT 
  'FCM Tokens Status' as check_type,
  app_type,
  COUNT(*) as token_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Users have tokens'
    ELSE '⚠️ No tokens - Users need to login to apps'
  END as status
FROM fcm_tokens
WHERE is_active = true
GROUP BY app_type;

-- ============================================================================
-- SUMMARY
-- ============================================================================
SELECT 
  '=== SETUP STATUS ===' as summary,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name = 'send_push_notification')
      AND EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_schema = 'public' AND trigger_name = 'new_booking_notification')
      AND EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_schema = 'public' AND trigger_name = 'payment_success_notification')
      AND EXISTS (SELECT 1 FROM fcm_tokens WHERE is_active = true)
    THEN '✅ Database setup complete! Next: Deploy edge function (see DEPLOY_EDGE_FUNCTION.md)'
    ELSE '❌ Some components missing - Fix above issues first'
  END AS overall_status;

-- ============================================================================
-- CRITICAL: Edge Function Must Be Deployed
-- ============================================================================
SELECT 
  '⚠️ IMPORTANT' as warning,
  'Edge function send-push-notification MUST be deployed for notifications to work' as message,
  'See: apps/user_app/DEPLOY_EDGE_FUNCTION.md for deployment instructions' as instruction;
