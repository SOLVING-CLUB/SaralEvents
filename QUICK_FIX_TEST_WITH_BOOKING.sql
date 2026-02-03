-- ============================================================================
-- QUICK TEST: Use booking_id (This works - I've fixed this case)
-- ============================================================================
-- The notification system has a bug where it tries to access o.vendor_id from orders table.
-- I've fixed the ORDER_VENDOR_ARRIVED case to use bookings instead.
-- So test with booking_id, not order_id.
-- ============================================================================

-- Step 1: Get a booking ID
SELECT 
  b.id as booking_id,
  b.status,
  b.milestone_status,
  b.user_id,
  b.vendor_id
FROM bookings b
WHERE b.status != 'cancelled'
LIMIT 1;

-- Step 2: Test with booking_id (THIS WORKS - I've fixed this)
-- IMPORTANT: First run FIX_DEDUPE_KEY_UNIQUE_INDEX.sql to fix the unique constraint issue
-- Then replace 'YOUR_BOOKING_ID' with the actual UUID from Step 1 (format: '550e8400-e29b-41d4-a716-446655440000')
SELECT notify_vendor_arrived(
  p_booking_id := 'YOUR_BOOKING_ID'::UUID,  -- Replace with actual UUID from Step 1
  p_order_id := NULL
);

-- Step 3: Check if notification was created
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
WHERE ne.event_code = 'ORDER_VENDOR_ARRIVED'
ORDER BY ne.created_at DESC
LIMIT 5;

-- ============================================================================
-- NOTE: Other notification events that use order_id still have the bug.
-- They need to be fixed to get vendor_id from bookings table.
-- For now, test only with booking_id-based notifications.
-- ============================================================================
