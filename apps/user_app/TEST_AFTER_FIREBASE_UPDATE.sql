-- ============================================================================
-- TEST NOTIFICATION AFTER FIREBASE ADMIN SDK UPDATE
-- Run this to test if the deprecation issue is fixed
-- ============================================================================

-- Test notification with the updated Firebase Admin SDK compatible authentication
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Firebase Admin SDK Test',
  'Testing after updating to Firebase Admin SDK compatible authentication. This should work now!',
  '{"type":"test","updated":"firebase_admin_sdk"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);

-- ============================================================================
-- EXPECTED RESULTS
-- ============================================================================

-- 1. Function should return:
--    {"message":"Notification request queued","success":true,"request_id":X}

-- 2. Check Dashboard logs:
--    Go to: Supabase Dashboard > Edge Functions > send-push-notification > Logs
--    Should see:
--    - "Fetched 1 tokens for user..."
--    - No deprecation warnings
--    - "Sent notification successfully" (if successful)

-- 3. Check your device:
--    You should receive the notification on your device

-- ============================================================================
-- IF IT STILL DOESN'T WORK
-- ============================================================================

-- Check Dashboard logs for:
-- - "Failed to get access token" → Google Auth Library issue
-- - "FCM API error: ..." → FCM API issue
-- - "No active tokens found" → Token issue

-- Share the error message from logs if you need help!
