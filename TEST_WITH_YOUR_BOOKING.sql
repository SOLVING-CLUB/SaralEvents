-- ============================================================================
-- TEST: Notification System with Your Booking ID
-- ============================================================================
-- Booking ID: d7126e7e-5324-4275-ab15-637635519fe1
-- Status: completed
-- Milestone: setup_confirmed
-- ============================================================================

-- Step 1: Test notify_vendor_arrived
SELECT notify_vendor_arrived(
  p_booking_id := 'd7126e7e-5324-4275-ab15-637635519fe1'::UUID,
  p_order_id := NULL
) as result;

-- Step 2: Check if notification event was created
SELECT 
  ne.event_id,
  ne.event_code,
  ne.booking_id,
  ne.order_id,
  ne.processed,
  ne.created_at
FROM notification_events ne
WHERE ne.booking_id = 'd7126e7e-5324-4275-ab15-637635519fe1'::UUID
  AND ne.event_code = 'ORDER_VENDOR_ARRIVED'
ORDER BY ne.created_at DESC
LIMIT 5;

-- Step 3: Check if notifications were created
SELECT 
  COALESCE(n.notification_id::text, n.id::text, 'N/A') as notification_id,
  n.event_id,
  n.recipient_role,
  n.recipient_user_id,
  n.recipient_vendor_id,
  n.title,
  n.body,
  n.status,
  n.type,
  n.dedupe_key,
  n.created_at
FROM notifications n
WHERE n.event_id IN (
  SELECT event_id 
  FROM notification_events 
  WHERE booking_id = 'd7126e7e-5324-4275-ab15-637635519fe1'::UUID
    AND event_code = 'ORDER_VENDOR_ARRIVED'
)
ORDER BY n.created_at DESC;

-- Step 4: Check notification logs (if push notifications were attempted)
SELECT 
  nl.log_id,
  nl.notification_id,
  nl.channel,
  nl.status,
  nl.error_message,
  nl.attempted_at
FROM notification_logs nl
WHERE nl.notification_id IN (
  SELECT COALESCE(n.notification_id, n.id::uuid)
  FROM notifications n
  WHERE n.event_id IN (
    SELECT event_id 
    FROM notification_events 
    WHERE booking_id = 'd7126e7e-5324-4275-ab15-637635519fe1'::UUID
      AND event_code = 'ORDER_VENDOR_ARRIVED'
  )
)
ORDER BY nl.attempted_at DESC;

-- ============================================================================
-- SUMMARY: What to expect
-- ============================================================================
-- 1. notify_vendor_arrived() should return a JSON object with event_id
-- 2. notification_events table should have 1 new row with event_code 'ORDER_VENDOR_ARRIVED'
-- 3. notifications table should have 1 new row with:
--    - recipient_role: 'USER'
--    - title: 'Vendor arrived'
--    - body: 'Vendor has arrived at your location'
-- 4. notification_logs may or may not have entries (depends on push notification setup)
-- ============================================================================
