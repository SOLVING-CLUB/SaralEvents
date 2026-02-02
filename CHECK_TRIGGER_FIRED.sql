-- ============================================================================
-- CHECK: Did the Payment Trigger Fire?
-- ============================================================================

-- Step 1: Check pg_net queue for notification requests
-- Look for requests to send-push-notification that happened after the update
SELECT 
  'Notification Requests After Update' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅ Payment notification request'
    ELSE 'Other request'
  END as request_type
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- Step 2: Check if the trigger exists and is active
SELECT 
  'Trigger Status' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';

-- Step 3: Check the notify_payment_success function
SELECT 
  'Function Status' as check_type,
  routine_name,
  routine_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'notify_payment_success';

-- Step 4: Check the updated payment details
SELECT 
  'Updated Payment Details' as check_type,
  pm.id as payment_id,
  pm.booking_id,
  pm.status,
  pm.updated_at,
  b.user_id,
  vp.user_id as vendor_user_id,
  CASE 
    WHEN b.user_id IS NULL THEN '❌ No user_id'
    ELSE '✅ Has user_id'
  END as user_status,
  CASE 
    WHEN vp.user_id IS NULL THEN '❌ No vendor_user_id'
    ELSE '✅ Has vendor_user_id'
  END as vendor_status
FROM payment_milestones pm
JOIN bookings b ON b.id = pm.booking_id
LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
WHERE pm.id = 'cda32086-f5e7-424d-a382-9fe1fb99852f';

-- Step 5: Check if FCM tokens exist for the user and vendor
SELECT 
  'FCM Tokens Check' as check_type,
  ft.user_id,
  ft.app_type,
  ft.is_active,
  COUNT(*) as token_count
FROM payment_milestones pm
JOIN bookings b ON b.id = pm.booking_id
LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
LEFT JOIN fcm_tokens ft ON (
  (ft.user_id = b.user_id AND ft.app_type = 'user_app')
  OR (ft.user_id = vp.user_id AND ft.app_type = 'vendor_app')
)
WHERE pm.id = 'cda32086-f5e7-424d-a382-9fe1fb99852f'
  AND ft.is_active = true
GROUP BY ft.user_id, ft.app_type, ft.is_active;
