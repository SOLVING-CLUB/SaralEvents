-- ============================================================================
-- DIAGNOSTIC QUERIES - Notification Not Received
-- Run these to find the issue
-- ============================================================================

-- Query 1: Check FCM tokens for recent activity
SELECT 
  'FCM Tokens Check' as check_type,
  COUNT(*) as total_tokens,
  COUNT(CASE WHEN is_active = true THEN 1 END) as active_tokens,
  COUNT(CASE WHEN app_type = 'user_app' AND is_active = true THEN 1 END) as active_user_app_tokens,
  COUNT(CASE WHEN app_type = 'vendor_app' AND is_active = true THEN 1 END) as active_vendor_app_tokens,
  MAX(updated_at) as most_recent_update
FROM fcm_tokens;

-- Query 2: Check tokens for a specific user (replace USER_ID)
-- First, get a user ID to test with
SELECT 
  'Available Users' as check_type,
  u.id as user_id,
  u.email,
  COUNT(ft.id) as token_count,
  COUNT(CASE WHEN ft.is_active = true THEN 1 END) as active_token_count,
  MAX(ft.updated_at) as last_token_update
FROM auth.users u
LEFT JOIN fcm_tokens ft ON ft.user_id = u.id
GROUP BY u.id, u.email
HAVING COUNT(CASE WHEN ft.is_active = true THEN 1 END) > 0
ORDER BY MAX(ft.updated_at) DESC
LIMIT 5;

-- Query 3: Detailed token check (use a user ID from Query 2)
-- Replace 'USER_ID_HERE' with actual user ID
SELECT 
  'Token Details' as check_type,
  ft.id,
  ft.user_id,
  ft.app_type,
  ft.is_active,
  LENGTH(ft.token) as token_length,
  LEFT(ft.token, 30) || '...' as token_preview,
  ft.created_at,
  ft.updated_at,
  CASE 
    WHEN ft.updated_at >= NOW() - INTERVAL '1 hour' THEN '✅ Recent'
    WHEN ft.updated_at >= NOW() - INTERVAL '24 hours' THEN '⚠️ Old (24h+)'
    ELSE '❌ Very Old'
  END as token_freshness
FROM fcm_tokens ft
WHERE ft.is_active = true
ORDER BY ft.updated_at DESC
LIMIT 10;

-- Query 4: Check recent edge function requests (if pg_net is available)
SELECT 
  'Recent Requests' as check_type,
  COUNT(*) as total_requests,
  MAX(created_at) as most_recent_request
FROM net.http_request_queue
WHERE created_at >= NOW() - INTERVAL '1 hour';

-- Query 5: Test notification with a user that has active tokens
-- This will help identify if the issue is with the user or the system
-- Replace USER_ID with a user ID from Query 2
SELECT 
  'Test Notification' as check_type,
  send_push_notification(
    (SELECT id FROM auth.users 
     WHERE id IN (SELECT user_id FROM fcm_tokens WHERE is_active = true LIMIT 1)
     LIMIT 1)::UUID,
    'Diagnostic Test',
    'Testing notification system - checking logs',
    '{"type":"diagnostic","test":true}'::JSONB,
    NULL,
    ARRAY['user_app']::TEXT[]
  ) as result;
