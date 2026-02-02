-- ============================================================================
-- CHECK: Vendor Notification Results
-- ============================================================================

-- Step 1: Check pg_net queue for notification requests
-- This shows if notifications were sent
SELECT 
  '🔍 pg_net Queue - Notification Requests' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅✅✅ Notification request sent!'
    ELSE 'Other request'
  END as result
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- Step 2: Show ALL recent pg_net requests
SELECT 
  'All Recent pg_net Requests' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 20;

-- Step 3: Count notification requests
SELECT 
  'Notification Request Count' as check_type,
  COUNT(*) as total_notification_requests,
  MAX(id) as latest_request_id,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Notifications were sent'
    ELSE '❌ No notification requests found'
  END as status
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%';

-- Step 4: Verify booking status
SELECT 
  'Booking Status Verification' as check_type,
  id,
  status,
  updated_at,
  CASE 
    WHEN status = 'completed' THEN '✅ Booking is completed'
    ELSE 'Status: ' || status
  END as booking_status
FROM bookings
WHERE id = 'f2c40bcb-18de-416d-9030-128c1a9ab9af';

-- Step 5: Check vendor FCM tokens
SELECT 
  'Vendor FCM Tokens Status' as check_type,
  vp.user_id as vendor_user_id,
  vp.business_name,
  ft.token as fcm_token_preview,
  ft.is_active,
  CASE 
    WHEN ft.is_active = true THEN '✅ Active token - should receive notification'
    ELSE '❌ No active token - notification will fail'
  END as token_status
FROM vendor_profiles vp
LEFT JOIN fcm_tokens ft ON ft.user_id = vp.user_id AND ft.app_type = 'vendor_app' AND ft.is_active = true
WHERE vp.id = 'bf25a30a-4ab6-4d2b-b879-35ceb38653a3'; -- Sun City Farmhouse vendor_id
