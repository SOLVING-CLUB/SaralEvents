-- ============================================================================
-- COMPLETE FIX: Run this before testing notifications
-- ============================================================================
-- This fixes the dedupe_key unique index issue
-- ============================================================================

-- Step 1: Fix dedupe_key unique index
DROP INDEX IF EXISTS idx_notifications_dedupe_key;
CREATE UNIQUE INDEX idx_notifications_dedupe_key 
ON notifications(dedupe_key) 
WHERE dedupe_key IS NOT NULL;

-- Step 2: Verify index was created
SELECT 
  '✅ Unique index created' as status,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'notifications'
  AND indexname = 'idx_notifications_dedupe_key';

-- Step 3: Get a test booking ID
SELECT 
  b.id as booking_id,
  b.status,
  b.milestone_status,
  b.user_id,
  b.vendor_id,
  'Copy this UUID for testing' as instruction
FROM bookings b
WHERE b.status != 'cancelled'
LIMIT 1;

-- Step 4: Test notification (replace UUID with one from Step 3)
-- SELECT notify_vendor_arrived(
--   p_booking_id := 'PASTE_UUID_HERE'::UUID,
--   p_order_id := NULL
-- );

-- Step 5: Check if notification was created
-- SELECT 
--   ne.event_id,
--   ne.event_code,
--   ne.booking_id,
--   ne.processed,
--   COALESCE(n.notification_id::text, n.id::text, 'N/A') as notification_id,
--   n.recipient_role,
--   n.title,
--   n.body,
--   n.status
-- FROM notification_events ne
-- LEFT JOIN notifications n ON n.event_id = ne.event_id
-- WHERE ne.event_code = 'ORDER_VENDOR_ARRIVED'
-- ORDER BY ne.created_at DESC
-- LIMIT 5;
