-- ============================================================================
-- SIMPLE TEST: Notification System
-- ============================================================================
-- This is the easiest way to test - just run each section
-- ============================================================================

-- ============================================================================
-- TEST 1: Get a real booking ID to use
-- ============================================================================
SELECT 
  b.id as booking_id,
  b.status,
  b.milestone_status,
  b.user_id,
  b.vendor_id,
  'Use this ID in the next query' as instruction
FROM bookings b
WHERE b.status != 'cancelled'
LIMIT 1;

-- ============================================================================
-- TEST 2: Test RPC Function - Vendor Arrived
-- ============================================================================
-- IMPORTANT: Use booking_id (not order_id) - I've already fixed this case
-- Copy the booking_id from TEST 1 and paste it below (replace the UUID)
-- Example UUID format: '550e8400-e29b-41d4-a716-446655440000'
SELECT notify_vendor_arrived(
  p_booking_id := 'PASTE_BOOKING_ID_HERE'::UUID,  -- Replace with actual UUID from TEST 1
  p_order_id := NULL
);

-- ============================================================================
-- TEST 3: Check if notification was created
-- ============================================================================
SELECT 
  ne.event_id,
  ne.event_code,
  ne.booking_id,
  ne.processed,
  COALESCE(n.notification_id::text, n.id::text, 'N/A') as notification_id,
  n.recipient_role,
  n.title,
  n.body,
  n.status,
  n.type
FROM notification_events ne
LEFT JOIN notifications n ON n.event_id = ne.event_id
WHERE ne.event_code = 'ORDER_VENDOR_ARRIVED'
ORDER BY ne.created_at DESC
LIMIT 5;

-- ============================================================================
-- TEST 4: Test Database Trigger - Update Booking Status
-- ============================================================================
-- Copy a booking_id from TEST 1 and paste it below
UPDATE bookings 
SET status = 'confirmed', 
    milestone_status = 'accepted',
    updated_at = NOW()
WHERE id = 'PASTE_BOOKING_ID_HERE'::UUID;  -- Replace with actual UUID

-- ============================================================================
-- TEST 5: Check if trigger created notification
-- ============================================================================
-- Use the same booking_id from TEST 4
SELECT 
  ne.event_id,
  ne.event_code,
  ne.booking_id,
  ne.processed,
  COALESCE(n.notification_id::text, n.id::text, 'N/A') as notification_id,
  n.recipient_role,
  n.title,
  n.body,
  n.status
FROM notification_events ne
LEFT JOIN notifications n ON n.event_id = ne.event_id
WHERE ne.event_code = 'ORDER_STATUS_CHANGED'
  AND ne.booking_id = 'PASTE_BOOKING_ID_HERE'::UUID  -- Replace with actual UUID
ORDER BY ne.created_at DESC;

-- ============================================================================
-- TEST 6: View all recent notifications (no UUID needed)
-- ============================================================================
SELECT 
  COALESCE(n.notification_id::text, n.id::text, 'N/A') as notification_id,
  n.title,
  n.body,
  n.recipient_role,
  n.status,
  n.type,
  n.created_at
FROM notifications n
ORDER BY n.created_at DESC
LIMIT 10;

-- ============================================================================
-- TEST 7: View notification logs (no UUID needed)
-- ============================================================================
SELECT 
  nl.log_id,
  nl.notification_id,
  nl.status,
  nl.channel,
  nl.error_message,
  nl.attempted_at,
  n.title,
  n.recipient_role
FROM notification_logs nl
LEFT JOIN notifications n ON (
  n.notification_id = nl.notification_id 
  OR n.id::text = nl.notification_id::text  -- fallback for old structure
)
ORDER BY nl.attempted_at DESC
LIMIT 10;

-- ============================================================================
-- TEST 8: Overall system health (no UUID needed)
-- ============================================================================
SELECT 
  'Total Events' as metric,
  COUNT(*)::text as value
FROM notification_events
UNION ALL
SELECT 
  'Processed Events',
  COUNT(*)::text
FROM notification_events
WHERE processed = true
UNION ALL
SELECT 
  'Pending Events',
  COUNT(*)::text
FROM notification_events
WHERE processed = false
UNION ALL
SELECT 
  'Total Notifications',
  COUNT(*)::text
FROM notifications
UNION ALL
SELECT 
  'Sent Notifications',
  COUNT(*)::text
FROM notifications
WHERE status = 'SENT'
UNION ALL
SELECT 
  'Failed Notifications',
  COUNT(*)::text
FROM notifications
WHERE status = 'FAILED';
