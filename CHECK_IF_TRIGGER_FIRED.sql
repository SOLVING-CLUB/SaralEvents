-- ============================================================================
-- CHECK: Did Payment Trigger Fire?
-- ============================================================================

-- Step 1: Check pg_net queue for notification requests
-- This is the KEY check - if trigger fired, there should be a request here
SELECT 
  'pg_net Queue - Did Trigger Fire?' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅ TRIGGER FIRED - Notification request found'
    ELSE 'Other request'
  END as trigger_status
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- Step 2: Check ALL recent pg_net requests (to see if anything was queued)
SELECT 
  'All Recent pg_net Requests' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅ Notification request'
    ELSE 'Other'
  END as request_type
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 20;

-- Step 3: Verify trigger exists
SELECT 
  'Trigger Exists?' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  CASE 
    WHEN trigger_name IS NOT NULL THEN '✅ Trigger exists'
    ELSE '❌ Trigger missing'
  END as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';

-- Step 4: Check payment details - verify user_id and vendor_user_id exist
SELECT 
  'Payment User/Vendor IDs' as check_type,
  pm.id as payment_id,
  pm.status,
  b.user_id,
  vp.user_id as vendor_user_id,
  CASE 
    WHEN b.user_id IS NULL THEN '❌ Missing user_id'
    WHEN vp.user_id IS NULL THEN '⚠️ Missing vendor_user_id'
    ELSE '✅ Both IDs present'
  END as id_status
FROM payment_milestones pm
JOIN bookings b ON b.id = pm.booking_id
LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
WHERE pm.id = 'cda32086-f5e7-424d-a382-9fe1fb99852f';

-- Step 5: Check if the trigger condition would match
-- The trigger has: WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
-- Payment status is 'held_in_escrow', so it should match
SELECT 
  'Trigger Condition Check' as check_type,
  pm.id,
  pm.status,
  CASE 
    WHEN pm.status IN ('paid', 'held_in_escrow', 'released') THEN '✅ Status matches trigger condition'
    ELSE '❌ Status does NOT match trigger condition'
  END as condition_match
FROM payment_milestones pm
WHERE pm.id = 'cda32086-f5e7-424d-a382-9fe1fb99852f';
