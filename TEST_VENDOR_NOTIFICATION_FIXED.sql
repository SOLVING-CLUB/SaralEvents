-- ============================================================================
-- TEST: Vendor App Notification - Fixed Version
-- ============================================================================

-- Step 1: Check FCM tokens for the vendors
SELECT 
  'Vendor FCM Tokens Check' as check_type,
  vp.id as vendor_id,
  vp.user_id as vendor_user_id,
  vp.business_name,
  ft.token as fcm_token_preview,
  ft.app_type,
  ft.is_active,
  CASE 
    WHEN ft.is_active = true THEN '✅ Active token'
    ELSE '❌ No active token'
  END as token_status
FROM vendor_profiles vp
LEFT JOIN fcm_tokens ft ON ft.user_id = vp.user_id AND ft.app_type = 'vendor_app' AND ft.is_active = true
WHERE vp.user_id IN (
  '777e7e48-388c-420e-89b9-85693197e0b7', -- Sun City Farmhouse
  'ad73265c-4877-4a94-8394-5c455cc2a012'  -- Other vendor
)
ORDER BY vp.business_name;

-- Step 2: Test notification to Sun City Farmhouse vendor
SELECT 
  'Test Notification - Sun City Farmhouse' as check_type,
  send_push_notification(
    '777e7e48-388c-420e-89b9-85693197e0b7'::UUID, -- Sun City Farmhouse vendor_user_id
    'Test Notification - Vendor App',
    'This is a test notification for Sun City Farmhouse vendor app. If you receive this, vendor notifications are working!',
    jsonb_build_object(
      'type', 'test',
      'test_type', 'vendor_app_notification',
      'vendor', 'Sun City Farmhouse',
      'timestamp', NOW()::TEXT
    ),
    NULL,
    ARRAY['vendor_app']::TEXT[] -- IMPORTANT: Only send to vendor_app
  ) as test_result;

-- Step 3: Test notification to other vendor
SELECT 
  'Test Notification - Other Vendor' as check_type,
  send_push_notification(
    'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID, -- Other vendor_user_id
    'Test Notification - Vendor App',
    'This is a test notification for vendor app. If you receive this, vendor notifications are working!',
    jsonb_build_object(
      'type', 'test',
      'test_type', 'vendor_app_notification',
      'timestamp', NOW()::TEXT
    ),
    NULL,
    ARRAY['vendor_app']::TEXT[] -- IMPORTANT: Only send to vendor_app
  ) as test_result;

-- Step 4: FIRST - Fix the booking_status_updates trigger (if not already fixed)
-- Run FIX_BOOKING_STATUS_UPDATE_TRIGGER.sql first, then continue

-- Step 5: Test booking status change notification
-- Update the booking status to trigger vendor notification
-- This should now work after fixing the trigger
UPDATE bookings
SET status = 'completed', -- Change from 'confirmed' to 'completed'
    updated_at = NOW()
WHERE id = 'f2c40bcb-18de-416d-9030-128c1a9ab9af'
  AND status = 'confirmed';

-- Step 6: Check pg_net queue for notification requests
SELECT 
  'pg_net Queue - Vendor Notification Requests' as check_type,
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
LIMIT 10;

-- Step 7: Verify booking was updated
SELECT 
  'Booking Update Verification' as check_type,
  id,
  status,
  updated_at,
  CASE 
    WHEN status = 'completed' THEN '✅ Updated to completed - vendor should receive notification'
    ELSE 'Status: ' || status
  END as update_status
FROM bookings
WHERE id = 'f2c40bcb-18de-416d-9030-128c1a9ab9af';
