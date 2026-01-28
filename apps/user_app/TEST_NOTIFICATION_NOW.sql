-- ============================================================================
-- TEST NOTIFICATION RIGHT NOW
-- Run this to test if send_push_notification function works
-- ============================================================================

-- Test the function with the user from the check
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Test Notification',
  'This is a test notification. If you receive this, notifications are working!',
  jsonb_build_object(
    'type', 'test',
    'timestamp', NOW()::TEXT,
    'test_id', gen_random_uuid()::TEXT
  ),
  NULL,
  ARRAY['user_app']::TEXT[]
) as test_result;

-- ============================================================================
-- WHAT TO EXPECT
-- ============================================================================
-- Expected Result (if working):
-- {
--   "success": true,
--   "request_id": 12345,
--   "message": "Notification request queued"
-- }
--
-- If you get this, the function works! Check:
-- 1. Your device for the notification
-- 2. Supabase Dashboard > Edge Functions > send-push-notification > Logs
-- 3. net.http_request_queue table (should have a new entry)
--
-- If you get an error, check:
-- 1. Edge function is deployed: supabase functions list
-- 2. FCM secret is set: supabase secrets list
-- 3. Check the error message for details
