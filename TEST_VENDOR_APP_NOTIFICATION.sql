-- ============================================================================
-- TEST: Vendor App Notification
-- ============================================================================

-- Step 1: Get vendor user_id and check FCM tokens
SELECT 
  'Vendor User & FCM Tokens' as check_type,
  vp.id as vendor_id,
  vp.user_id as vendor_user_id,
  vp.business_name,
  ft.token as fcm_token_preview,
  ft.app_type,
  ft.is_active,
  CASE 
    WHEN ft.is_active = true THEN '✅ Active token for vendor_app'
    ELSE '❌ No active token'
  END as token_status
FROM vendor_profiles vp
LEFT JOIN fcm_tokens ft ON ft.user_id = vp.user_id AND ft.app_type = 'vendor_app' AND ft.is_active = true
ORDER BY vp.created_at DESC
LIMIT 5;

-- Step 2: Test notification to vendor app
-- Replace the vendor_user_id with an actual vendor user_id from Step 1
SELECT 
  'Test Vendor Notification' as check_type,
  send_push_notification(
    (SELECT user_id FROM vendor_profiles ORDER BY created_at DESC LIMIT 1), -- Get latest vendor user_id
    'Test Notification - Vendor App',
    'This is a test notification for the vendor app. If you receive this, vendor notifications are working!',
    jsonb_build_object(
      'type', 'test',
      'test_type', 'vendor_app_notification',
      'timestamp', NOW()::TEXT
    ),
    NULL,
    ARRAY['vendor_app']::TEXT[] -- IMPORTANT: Only send to vendor_app
  ) as test_result;

-- Step 3: Test with specific vendor (if you know the vendor_user_id)
-- Uncomment and replace <vendor_user_id> with actual vendor user_id
/*
SELECT 
  'Test Specific Vendor' as check_type,
  send_push_notification(
    '<vendor_user_id>'::UUID, -- Replace with actual vendor user_id
    'Test Notification - Vendor App',
    'This is a test notification for the vendor app',
    jsonb_build_object('type', 'test'),
    NULL,
    ARRAY['vendor_app']::TEXT[]
  ) as test_result;
*/

-- Step 4: Check pg_net queue for notification request
SELECT 
  'pg_net Queue - Vendor Notification Request' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅ Notification request sent'
    ELSE 'Other request'
  END as result
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 5;

-- Step 5: Test booking status change notification (vendor should receive)
-- Get a booking to test with
SELECT 
  'Test Booking for Vendor Notification' as check_type,
  b.id as booking_id,
  b.user_id,
  b.vendor_id,
  b.status,
  vp.user_id as vendor_user_id,
  vp.business_name
FROM bookings b
JOIN vendor_profiles vp ON vp.id = b.vendor_id
WHERE vp.user_id IS NOT NULL
ORDER BY b.created_at DESC
LIMIT 1;

-- Step 6: Update booking status to trigger vendor notification
-- Replace <booking_id> with actual booking_id from Step 5
-- This will trigger notify_booking_status_change which should send to vendor
/*
UPDATE bookings
SET status = 'confirmed',
    updated_at = NOW()
WHERE id = '<booking_id>'; -- Replace with actual booking_id
*/
