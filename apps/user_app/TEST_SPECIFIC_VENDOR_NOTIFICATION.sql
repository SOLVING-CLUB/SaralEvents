-- ============================================================================
-- TEST NOTIFICATION FOR SPECIFIC VENDOR
-- Use the vendor user_id from the diagnostic query
-- ============================================================================

-- Test notification for the vendor with active token
SELECT send_push_notification(
  '14eca5f2-e934-4142-a721-efa9aa4f69a8'::UUID,
  'Vendor Notification Test',
  'Testing notification for RDJ Music vendor. If you receive this, vendor notifications are working!',
  '{"type":"test","vendor_id":"14eca5f2-e934-4142-a721-efa9aa4f69a8"}'::JSONB,
  NULL,
  ARRAY['vendor_app']::TEXT[]
);

-- ============================================================================
-- EXPECTED RESULTS
-- ============================================================================

-- 1. Function should return:
--    {"message":"Notification request queued","success":true,"request_id":X}

-- 2. Check Dashboard logs:
--    Go to: Supabase Dashboard > Edge Functions > send-push-notification > Logs
--    Should see:
--    - "Fetched 1 tokens for user 14eca5f2-e934-4142-a721-efa9aa4f69a8 with appTypes: vendor_app"
--    - No errors

-- 3. Check vendor app:
--    - Vendor should receive notification on their device
--    - App should be running (foreground or background)

-- ============================================================================
-- IF NOT RECEIVED
-- ============================================================================

-- Check Dashboard logs for:
-- - "No active tokens found" → Token issue
-- - "FCM API error: ..." → FCM API issue
-- - "Failed to get access token" → FCM secret issue
