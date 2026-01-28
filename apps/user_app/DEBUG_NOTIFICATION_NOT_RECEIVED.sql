-- ============================================================================
-- DEBUG: Why Notification Not Received
-- Run this to check why notifications aren't reaching the device
-- ============================================================================

-- Step 1: Check FCM token status for the test user
SELECT 
  'FCM Token Status' as check_type,
  ft.id,
  ft.user_id,
  ft.app_type,
  ft.device_type,
  ft.is_active,
  ft.created_at,
  ft.updated_at,
  CASE 
    WHEN ft.is_active = true THEN '✅ Token is active'
    ELSE '❌ Token is inactive'
  END as token_status,
  CASE 
    WHEN ft.updated_at >= NOW() - INTERVAL '7 days' THEN '✅ Recent token'
    ELSE '⚠️ Token might be expired'
  END as token_freshness
FROM fcm_tokens ft
WHERE ft.user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012'
ORDER BY ft.updated_at DESC;

-- Step 2: Check recent notification requests
SELECT 
  'Recent Notification Requests' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
WHERE id >= 5  -- Your test requests (id 5 and 6)
ORDER BY id DESC
LIMIT 5;

-- Step 3: Verify user has active token
SELECT 
  'User Token Verification' as check_type,
  u.id as user_id,
  u.email,
  COUNT(ft.id) as token_count,
  COUNT(CASE WHEN ft.is_active = true THEN 1 END) as active_tokens,
  STRING_AGG(DISTINCT ft.app_type, ', ') as app_types,
  MAX(ft.updated_at) as latest_token_update
FROM auth.users u
LEFT JOIN fcm_tokens ft ON ft.user_id = u.id
WHERE u.id = 'ad73265c-4877-4a94-8394-5c455cc2a012'
GROUP BY u.id, u.email;

-- Step 4: Check if edge function is processing requests
-- Note: Check Supabase Dashboard > Edge Functions > send-push-notification > Logs
-- Look for errors like:
-- - "No active tokens found"
-- - "FCM API error"
-- - "Invalid token"

-- ============================================================================
-- COMMON ISSUES & SOLUTIONS
-- ============================================================================

-- Issue 1: Token is inactive
-- Solution: User needs to login to app again to refresh token
/*
UPDATE fcm_tokens
SET is_active = true
WHERE user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012'
AND is_active = false;
*/

-- Issue 2: Token is old/expired
-- Solution: User needs to open the app to refresh token
-- The app will automatically update the token when opened

-- Issue 3: Wrong app_type
-- Solution: Verify app_type matches the app being used
/*
SELECT * FROM fcm_tokens 
WHERE user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012'
AND app_type = 'user_app';  -- Should match the app you're testing with
*/

-- ============================================================================
-- MANUAL CHECKS REQUIRED
-- ============================================================================

-- 1. Check Supabase Dashboard > Edge Functions > send-push-notification > Logs
--    Look for error messages

-- 2. Verify app is running or in background (not force-stopped)

-- 3. Check device notification permissions are enabled

-- 4. Try opening the app to refresh FCM token
