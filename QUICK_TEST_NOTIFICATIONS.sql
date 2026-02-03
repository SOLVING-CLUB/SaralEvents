-- ============================================================================
-- QUICK TEST: Notification System
-- ============================================================================
-- Run these queries one by one to quickly test the notification system
-- ============================================================================

-- STEP 1: Get a test booking ID
DO $$
DECLARE
  test_booking_id UUID;
BEGIN
  -- Get a valid booking ID
  SELECT id INTO test_booking_id
  FROM bookings
  WHERE status != 'cancelled'
  LIMIT 1;
  
  IF test_booking_id IS NULL THEN
    RAISE NOTICE 'No bookings found. Please create a booking first.';
  ELSE
    RAISE NOTICE 'Using booking ID: %', test_booking_id;
    
    -- Test RPC Function - Vendor Arrived
    PERFORM notify_vendor_arrived(
      p_booking_id := test_booking_id,
      p_order_id := NULL
    );
    
    RAISE NOTICE '✅ RPC function called successfully';
  END IF;
END $$;

-- Show the booking ID that was used (if any)
SELECT 
  b.id as booking_id,
  b.status,
  b.milestone_status,
  b.user_id,
  b.vendor_id
FROM bookings b
WHERE b.status != 'cancelled'
LIMIT 1;

-- STEP 3: Check if notification was created
-- Check if notifications table has the correct structure
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'notifications' 
      AND column_name = 'notification_id'
    )
    THEN '✅ notifications table has correct structure'
    ELSE '❌ notifications table needs fixing - Run FIX_NOTIFICATIONS_TABLE.sql'
  END as table_status;

-- Check if notification was created (works with both old 'id' and new 'notification_id')
SELECT 
  ne.event_code,
  ne.booking_id,
  ne.processed,
  COALESCE(
    n.notification_id::text, 
    n.id::text,  -- fallback for old structure
    'N/A'
  ) as notification_id,
  n.recipient_role,
  n.title,
  n.body,
  n.status
FROM notification_events ne
LEFT JOIN notifications n ON n.event_id = ne.event_id
WHERE ne.event_code = 'ORDER_VENDOR_ARRIVED'
ORDER BY ne.created_at DESC
LIMIT 5;

-- STEP 4: Test Database Trigger - Update Booking Status
-- This will update the first available booking
DO $$
DECLARE
  test_booking_id UUID;
BEGIN
  -- Get a valid booking ID
  SELECT id INTO test_booking_id
  FROM bookings
  WHERE status != 'cancelled'
  LIMIT 1;
  
  IF test_booking_id IS NULL THEN
    RAISE NOTICE 'No bookings found. Please create a booking first.';
  ELSE
    RAISE NOTICE 'Updating booking ID: %', test_booking_id;
    
    -- Update booking status to trigger notification
    UPDATE bookings 
    SET status = 'confirmed', 
        milestone_status = 'accepted',
        updated_at = NOW()
    WHERE id = test_booking_id;
    
    RAISE NOTICE '✅ Booking updated. Check notifications below.';
  END IF;
END $$;

-- STEP 5: Check if trigger created notification
-- Get the most recent booking that was updated
WITH recent_booking AS (
  SELECT id as booking_id
  FROM bookings
  WHERE status = 'confirmed'
  ORDER BY updated_at DESC
  LIMIT 1
)
SELECT 
  ne.event_code,
  ne.booking_id,
  ne.processed,
  COALESCE(n.notification_id::text, n.id::text, 'N/A') as notification_id,
  n.recipient_role,
  n.title,
  n.body
FROM notification_events ne
LEFT JOIN notifications n ON n.event_id = ne.event_id
CROSS JOIN recent_booking rb
WHERE ne.event_code = 'ORDER_STATUS_CHANGED'
  AND ne.booking_id = rb.booking_id
ORDER BY ne.created_at DESC;

-- STEP 6: View all recent notifications
-- First check if table exists and what the primary key is called
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifications'
  AND column_name LIKE '%id%'
ORDER BY column_name;

-- Then view notifications (adjust column name if needed)
SELECT 
  n.title,
  n.body,
  n.recipient_role,
  n.status,
  n.type,
  n.created_at
FROM notifications n
ORDER BY n.created_at DESC
LIMIT 10;

-- STEP 7: Check notification logs (push notification attempts)
-- Use COALESCE to handle if notifications table doesn't exist or has different column name
SELECT 
  nl.log_id,
  nl.notification_id,
  nl.status,
  nl.channel,
  nl.error_message,
  nl.attempted_at
FROM notification_logs nl
ORDER BY nl.attempted_at DESC
LIMIT 10;

-- If notifications table exists, join it:
-- SELECT 
--   nl.status,
--   nl.channel,
--   nl.error_message,
--   n.title,
--   n.recipient_role
-- FROM notification_logs nl
-- LEFT JOIN notifications n ON (
--   n.notification_id = nl.notification_id 
--   OR n.id = nl.notification_id  -- fallback if primary key is 'id'
-- )
-- ORDER BY nl.attempted_at DESC
-- LIMIT 10;
