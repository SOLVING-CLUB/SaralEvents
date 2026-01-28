-- ============================================================================
-- CHECK EDGE FUNCTION EXECUTION
-- This helps verify if the edge function is actually processing requests
-- ============================================================================

-- Step 1: Check recent HTTP requests to edge function
-- Note: This shows queued requests, not the response
SELECT 
  'Recent Edge Function Requests' as check_type,
  id,
  url,
  method,
  -- Note: pg_net version differences - some columns may not exist
  -- Check Supabase Dashboard > Logs for detailed request/response info
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅ Edge function request'
    ELSE 'Other request'
  END as request_type
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- Step 2: Verify the exact token that should be sent
SELECT 
  'Token to Send' as check_type,
  ft.id as token_id,
  ft.user_id,
  ft.app_type,
  ft.is_active,
  LEFT(ft.token, 50) || '...' as token_preview,
  LENGTH(ft.token) as token_length,
  ft.updated_at,
  CASE 
    WHEN LENGTH(ft.token) < 50 THEN '❌ Token too short (invalid)'
    WHEN ft.token IS NULL OR ft.token = '' THEN '❌ Token is empty'
    ELSE '✅ Token looks valid'
  END as token_validity
FROM fcm_tokens ft
WHERE ft.user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012'
  AND ft.app_type = 'user_app'
  AND ft.is_active = true
ORDER BY ft.updated_at DESC
LIMIT 1;

-- Step 3: Test the exact payload that would be sent
SELECT 
  'Test Payload' as check_type,
  jsonb_build_object(
    'userId', 'ad73265c-4877-4a94-8394-5c455cc2a012',
    'title', 'Test Notification',
    'body', 'Testing edge function execution',
    'data', '{"type":"test"}'::jsonb,
    'imageUrl', NULL,
    'appTypes', ARRAY['user_app']::TEXT[]
  ) as payload;

-- ============================================================================
-- MANUAL CHECKS REQUIRED
-- ============================================================================

-- 1. Check Supabase Dashboard > Edge Functions > send-push-notification > Logs
--    Look for:
--    - "Fetched X tokens for user..."
--    - "Sent notification successfully"
--    - "FCM API error: ..."
--    - "No active tokens found"

-- 2. Check Supabase Dashboard > Logs > Postgres Logs
--    Look for any errors from send_push_notification function

-- 3. Verify FCM Service Account permissions in Firebase Console:
--    - Go to Firebase Console > Project Settings > Service Accounts
--    - Verify the service account has "Firebase Cloud Messaging API" enabled

-- ============================================================================
-- COMMON EDGE FUNCTION ERRORS
-- ============================================================================

-- Error 1: "No active tokens found"
-- Cause: Edge function can't find tokens (query issue or token not matching)
-- Fix: Verify token exists with exact user_id and app_type

-- Error 2: "FCM API error: invalid token"
-- Cause: FCM token is expired or invalid
-- Fix: User needs to open app to refresh token

-- Error 3: "FCM API error: permission denied"
-- Cause: FCM Service Account doesn't have permissions
-- Fix: Check Firebase Console > Service Accounts > Permissions

-- Error 4: "Failed to get access token"
-- Cause: FCM Service Account JSON is invalid or expired
-- Fix: Re-set FCM_SERVICE_ACCOUNT_BASE64 secret

-- ============================================================================
-- NEXT STEPS
-- ============================================================================

-- 1. Run this diagnostic
-- 2. Check Dashboard logs (most important!)
-- 3. Share the error message from logs
-- 4. Apply fix based on error
