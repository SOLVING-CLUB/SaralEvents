-- ============================================================================
-- VERIFY VENDOR APP AND CAMPAIGN NOTIFICATIONS
-- This script helps verify if vendor app and campaign notifications are working
-- ============================================================================

-- Step 1: Check vendor app FCM tokens
SELECT 
  'Vendor App Tokens' as check_type,
  ft.id,
  ft.user_id,
  u.email,
  ft.app_type,
  ft.is_active,
  ft.updated_at,
  LEFT(ft.token, 30) || '...' as token_preview,
  CASE 
    WHEN ft.is_active = true THEN '✅ Token is active'
    ELSE '❌ Token is inactive'
  END as token_status
FROM fcm_tokens ft
JOIN auth.users u ON u.id = ft.user_id
WHERE ft.app_type = 'vendor_app'
  AND ft.is_active = true
ORDER BY ft.updated_at DESC
LIMIT 10;

-- Step 2: Check if vendor has active tokens
SELECT 
  'Vendor Token Summary' as check_type,
  COUNT(*) as total_vendor_tokens,
  COUNT(CASE WHEN is_active = true THEN 1 END) as active_vendor_tokens,
  COUNT(DISTINCT user_id) as unique_vendors_with_tokens,
  MAX(updated_at) as latest_token_update
FROM fcm_tokens
WHERE app_type = 'vendor_app';

-- Step 3: Test vendor app notification
-- Replace 'VENDOR_USER_ID' with an actual vendor's auth.users.id
-- You can get this from: SELECT user_id FROM vendor_profiles LIMIT 1;
SELECT 
  'Test Vendor Notification' as check_type,
  send_push_notification(
    (SELECT user_id FROM vendor_profiles LIMIT 1)::UUID,  -- Replace with actual vendor user_id
    'Vendor App Test',
    'Testing vendor app notification. If you receive this, vendor notifications are working!',
    '{"type":"test","app":"vendor_app"}'::JSONB,
    NULL,
    ARRAY['vendor_app']::TEXT[]
  ) as result;

-- Step 4: Check campaign notifications table
SELECT 
  'Campaign Notifications' as check_type,
  id,
  title,
  target_audience,
  status,
  sent_count,
  failed_count,
  total_recipients,
  sent_at,
  created_at
FROM notification_campaigns
ORDER BY created_at DESC
LIMIT 10;

-- Step 5: Check campaign notification recipients
-- This shows which users/vendors would receive campaign notifications
SELECT 
  'Campaign Recipients (All Users)' as check_type,
  COUNT(DISTINCT ft.user_id) as users_with_tokens,
  COUNT(*) as total_tokens
FROM fcm_tokens ft
WHERE ft.app_type = 'user_app'
  AND ft.is_active = true;

SELECT 
  'Campaign Recipients (All Vendors)' as check_type,
  COUNT(DISTINCT ft.user_id) as vendors_with_tokens,
  COUNT(*) as total_tokens
FROM fcm_tokens ft
WHERE ft.app_type = 'vendor_app'
  AND ft.is_active = true;

-- Step 6: Test campaign notification for all users
-- This simulates what happens when a campaign is sent to "all_users"
SELECT 
  'Test Campaign - All Users' as check_type,
  send_push_notification(
    (SELECT id FROM auth.users WHERE email = 'karthikeyabalaji123@gmail.com' LIMIT 1)::UUID,
    'Campaign Test - All Users',
    'This is a test campaign notification for all users',
    '{"type":"campaign","campaign_id":"test"}'::JSONB,
    NULL,
    ARRAY['user_app']::TEXT[]
  ) as result;

-- Step 7: Test campaign notification for all vendors
-- This simulates what happens when a campaign is sent to "all_vendors"
-- Replace with actual vendor user_id
SELECT 
  'Test Campaign - All Vendors' as check_type,
  send_push_notification(
    (SELECT user_id FROM vendor_profiles LIMIT 1)::UUID,  -- Replace with actual vendor user_id
    'Campaign Test - All Vendors',
    'This is a test campaign notification for all vendors',
    '{"type":"campaign","campaign_id":"test"}'::JSONB,
    NULL,
    ARRAY['vendor_app']::TEXT[]
  ) as result;

-- ============================================================================
-- MANUAL CHECKS REQUIRED
-- ============================================================================

-- 1. Check Supabase Dashboard > Edge Functions > send-push-notification > Logs
--    Look for:
--    - "Fetched X tokens for user... with appTypes: vendor_app"
--    - "Fetched X tokens for user... with appTypes: user_app"
--    - Any errors

-- 2. Test from Company Web Dashboard:
--    - Go to Campaigns page
--    - Create a test campaign
--    - Target: "All Users" or "All Vendors"
--    - Send immediately
--    - Check campaign status and logs

-- 3. Verify vendor app receives notifications:
--    - Open vendor app
--    - Check if notifications are received
--    - Verify notification appears in correct app (vendor_app only)

-- ============================================================================
-- COMMON ISSUES
-- ============================================================================

-- Issue 1: No vendor tokens found
-- Solution: Vendor needs to login to vendor app to register token

-- Issue 2: Campaign notifications not sent
-- Solution: Check campaign status in notification_campaigns table
--           Check Dashboard logs for errors

-- Issue 3: Notifications going to wrong app
-- Solution: Verify appTypes parameter is set correctly:
--           - All Users → appTypes: ['user_app']
--           - All Vendors → appTypes: ['vendor_app']

-- ============================================================================
-- NEXT STEPS
-- ============================================================================

-- 1. Run this diagnostic script
-- 2. Check Dashboard logs for any errors
-- 3. Test campaign from Company Web Dashboard
-- 4. Verify notifications are received in correct apps
-- 5. Share results if issues found
