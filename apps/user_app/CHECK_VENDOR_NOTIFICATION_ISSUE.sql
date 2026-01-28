-- ============================================================================
-- CHECK WHY VENDOR NOTIFICATION NOT RECEIVED
-- Run this to diagnose vendor notification issues
-- ============================================================================

-- Step 1: Check if vendor has active tokens
SELECT 
  'Vendor Token Check' as check_type,
  ft.id,
  ft.user_id,
  u.email,
  vp.business_name,
  ft.app_type,
  ft.is_active,
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
JOIN auth.users u ON u.id = ft.user_id
LEFT JOIN vendor_profiles vp ON vp.user_id = ft.user_id
WHERE ft.app_type = 'vendor_app'
  AND ft.is_active = true
ORDER BY ft.updated_at DESC;

-- Step 2: Check which vendor was used in the test
-- Replace with the actual vendor user_id from your test
SELECT 
  'Test Vendor Info' as check_type,
  vp.id as vendor_profile_id,
  vp.user_id as vendor_user_id,
  vp.business_name,
  u.email,
  COUNT(ft.id) as token_count,
  COUNT(CASE WHEN ft.is_active = true THEN 1 END) as active_tokens
FROM vendor_profiles vp
JOIN auth.users u ON u.id = vp.user_id
LEFT JOIN fcm_tokens ft ON ft.user_id = vp.user_id AND ft.app_type = 'vendor_app'
WHERE vp.user_id = (SELECT user_id FROM vendor_profiles LIMIT 1)  -- Replace with actual vendor user_id
GROUP BY vp.id, vp.user_id, vp.business_name, u.email;

-- Step 3: Check recent notification requests
SELECT 
  'Recent Notification Requests' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
  AND id >= 10  -- Your test requests
ORDER BY id DESC
LIMIT 5;

-- Step 4: Verify FCM secret is set (check via Supabase Dashboard)
-- Go to: Supabase Dashboard > Project Settings > Edge Functions > Secrets
-- Should see: FCM_SERVICE_ACCOUNT_BASE64

-- Step 5: Test with a specific vendor user_id
-- First, get a vendor user_id that has an active token:
SELECT 
  'Vendor with Active Token' as check_type,
  ft.user_id,
  u.email,
  vp.business_name,
  ft.token as token_preview
FROM fcm_tokens ft
JOIN auth.users u ON u.id = ft.user_id
LEFT JOIN vendor_profiles vp ON vp.user_id = ft.user_id
WHERE ft.app_type = 'vendor_app'
  AND ft.is_active = true
ORDER BY ft.updated_at DESC
LIMIT 1;

-- Then use that user_id in the test:
-- SELECT send_push_notification(
--   'VENDOR_USER_ID_FROM_ABOVE'::UUID,
--   'Vendor Test',
--   'Testing vendor notification',
--   '{"type":"test"}'::JSONB,
--   NULL,
--   ARRAY['vendor_app']::TEXT[]
-- );

-- ============================================================================
-- COMMON ISSUES
-- ============================================================================

-- Issue 1: No vendor tokens found
-- Solution: Vendor needs to login to vendor app to register token

-- Issue 2: Token is inactive
-- Solution: Vendor needs to login to vendor app again

-- Issue 3: Wrong user_id used
-- Solution: Make sure you're using vendor_profiles.user_id (not vendor_profiles.id)

-- Issue 4: FCM secret not set or invalid
-- Solution: Re-set the FCM_SERVICE_ACCOUNT_BASE64 secret (see HOW_TO_CREATE_FCM_BASE64.md)

-- ============================================================================
-- MANUAL CHECKS REQUIRED
-- ============================================================================

-- 1. Check Supabase Dashboard > Edge Functions > send-push-notification > Logs
--    Look for request_id 12 (your vendor test)
--    Check for errors like:
--    - "No active tokens found"
--    - "Failed to get access token"
--    - "FCM API error: ..."

-- 2. Verify vendor app is running on device
--    - App should be open or in background
--    - Notification permissions enabled
--    - Device connected to internet

-- 3. Check FCM secret is set:
--    - Go to Supabase Dashboard > Project Settings > Edge Functions > Secrets
--    - Should see: FCM_SERVICE_ACCOUNT_BASE64

-- ============================================================================
-- NEXT STEPS
-- ============================================================================

-- 1. Run this diagnostic to check vendor tokens
-- 2. Check Dashboard logs for request_id 12
-- 3. Verify FCM secret is set correctly
-- 4. Test again with a vendor that has an active token
