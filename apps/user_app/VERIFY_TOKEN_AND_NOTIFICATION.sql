-- ============================================================================
-- VERIFY TOKEN AND NOTIFICATION STATUS
-- This helps verify if the token is being used correctly
-- ============================================================================

-- Step 1: Verify the token details
SELECT 
  'Token Verification' as check_type,
  id,
  user_id,
  LEFT(token, 30) || '...' as token_preview,
  LENGTH(token) as token_length,
  app_type,
  is_active,
  updated_at,
  CASE 
    WHEN LENGTH(token) > 100 THEN '✅ Token length looks valid'
    ELSE '❌ Token too short'
  END as token_validity,
  CASE 
    WHEN token LIKE 'f-%' THEN '✅ Token format looks valid (FCM v1)'
    WHEN token LIKE 'c%' THEN '✅ Token format looks valid (FCM legacy)'
    ELSE '⚠️ Token format unusual'
  END as token_format
FROM fcm_tokens
WHERE id = 'fc35ad0f-3a3c-4513-973a-8a57ef2295b8';

-- Step 2: Check recent notification requests
SELECT 
  'Recent Requests' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 5;

-- Step 3: Test notification with this specific token
-- Note: This will send a test notification to verify the token works
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Token Verification Test',
  'Testing with your specific token. If you receive this, the token is working!',
  '{"type":"test","token_id":"fc35ad0f-3a3c-4513-973a-8a57ef2295b8"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);

-- ============================================================================
-- WHAT TO CHECK NEXT
-- ============================================================================

-- 1. Check Supabase Dashboard > Edge Functions > send-push-notification > Logs
--    Look for:
--    - "Fetched 1 tokens for user..."
--    - "Sent notification successfully"
--    - Any error messages

-- 2. Check your device:
--    - Did you receive the notification?
--    - Is the app running (foreground or background)?
--    - Are notification permissions enabled?

-- 3. If notification not received:
--    - Check Dashboard logs for errors
--    - Verify app is not force-stopped
--    - Try opening the app to refresh token

-- ============================================================================
-- TOKEN ANALYSIS
-- ============================================================================

-- Your token:
-- - Length: ~170 characters ✅ (Valid FCM tokens are 100+ characters)
-- - Format: Starts with "f-" ✅ (FCM v1 token format)
-- - Status: Active ✅
-- - Updated: Recently (2026-01-26 07:09:28) ✅
-- - App Type: user_app ✅

-- The token looks completely valid! If notifications aren't working,
-- the issue is likely in:
-- 1. Edge function processing (check Dashboard logs)
-- 2. FCM API delivery (check Dashboard logs for FCM errors)
-- 3. Device/app state (app not running, permissions, etc.)
