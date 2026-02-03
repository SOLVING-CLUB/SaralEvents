-- ============================================================================
-- TEST NOTIFICATION SYSTEM
-- ============================================================================
-- Run these queries in Supabase SQL Editor to test the notification system
-- Run them one at a time and check the results
-- ============================================================================

-- ============================================================================
-- TEST 1: Check if all tables exist and their columns
-- ============================================================================
-- Check tables exist
SELECT 
  table_name,
  CASE 
    WHEN table_name IN ('notification_events', 'notifications', 'notification_logs') 
    THEN '✅ Exists'
    ELSE '❌ Missing'
  END as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('notification_events', 'notifications', 'notification_logs')
ORDER BY table_name;

-- Check notifications table columns
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifications'
ORDER BY ordinal_position;

-- ============================================================================
-- TEST 2: Check if all functions exist
-- ============================================================================
SELECT 
  routine_name,
  CASE 
    WHEN routine_name IN (
      'process_notification_event',
      'send_push_notification',
      'notify_vendor_arrived',
      'notify_vendor_setup_completed',
      'notify_vendor_cancelled_order',
      'notify_user_confirm_arrival',
      'notify_user_confirm_setup',
      'notify_user_cancelled_order',
      'notify_campaign_broadcast',
      'notify_vendor_decision',
      'notify_vendor_completed_order'
    )
    THEN '✅ Exists'
    ELSE '❌ Missing'
  END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'process_notification_event',
    'send_push_notification',
    'notify_vendor_arrived',
    'notify_vendor_setup_completed',
    'notify_vendor_cancelled_order',
    'notify_user_confirm_arrival',
    'notify_user_confirm_setup',
    'notify_user_cancelled_order',
    'notify_campaign_broadcast',
    'notify_vendor_decision',
    'notify_vendor_completed_order'
  )
ORDER BY routine_name;

-- ============================================================================
-- TEST 3: Test Manual RPC Function - Vendor Arrived
-- ============================================================================
-- First, get a valid booking_id and order_id (replace with actual IDs from your database)
-- SELECT id as booking_id FROM bookings LIMIT 1;
-- SELECT id as order_id FROM orders LIMIT 1;

-- Then test the RPC function:
-- SELECT notify_vendor_arrived(
--   p_booking_id := 'YOUR_BOOKING_ID_HERE'::UUID,
--   p_order_id := NULL
-- );

-- Check if notification was created:
-- First verify the notifications table structure
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications'
  ) THEN
    RAISE EXCEPTION 'notifications table does not exist. Please run STEP_02_CREATE_NOTIFICATION_TABLES.sql first.';
  END IF;
END $$;

SELECT 
  ne.event_id,
  ne.event_code,
  ne.booking_id,
  ne.order_id,
  ne.actor_role,
  ne.processed,
  COALESCE(n.notification_id::text, 'N/A') as notification_id,
  n.recipient_role,
  n.recipient_user_id,
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
-- TEST 4: Test Database Trigger - Booking Status Change
-- ============================================================================
-- First, get a booking to test with:
-- SELECT id, status, milestone_status, user_id, vendor_id 
-- FROM bookings 
-- WHERE status != 'cancelled' 
-- LIMIT 1;

-- Update booking status to trigger notification:
-- UPDATE bookings 
-- SET status = 'confirmed', 
--     milestone_status = 'accepted',
--     updated_at = NOW()
-- WHERE id = 'YOUR_BOOKING_ID_HERE'::UUID;

-- Check if notification was created:
SELECT 
  ne.event_id,
  ne.event_code,
  ne.booking_id,
  ne.actor_role,
  ne.processed,
  n.notification_id,
  n.recipient_role,
  n.title,
  n.body,
  n.status
FROM notification_events ne
LEFT JOIN notifications n ON n.event_id = ne.event_id
WHERE ne.event_code = 'ORDER_STATUS_CHANGED'
  AND ne.booking_id = 'YOUR_BOOKING_ID_HERE'::UUID
ORDER BY ne.created_at DESC
LIMIT 5;

-- ============================================================================
-- TEST 5: Test Payment Milestone Notification
-- ============================================================================
-- First, get a payment milestone to test with:
-- SELECT pm.id, pm.booking_id, pm.milestone_type, pm.status, pm.amount
-- FROM payment_milestones pm
-- WHERE pm.status = 'pending'
-- LIMIT 1;

-- Update payment milestone status to trigger notification:
-- UPDATE payment_milestones 
-- SET status = 'paid',
--     paid_at = NOW(),
--     updated_at = NOW()
-- WHERE id = 'YOUR_MILESTONE_ID_HERE'::UUID;

-- Check if notifications were created (should create for both USER and VENDOR):
SELECT 
  ne.event_id,
  ne.event_code,
  ne.booking_id,
  ne.payment_id,
  ne.actor_role,
  ne.processed,
  n.notification_id,
  n.recipient_role,
  n.recipient_user_id,
  n.recipient_vendor_id,
  n.title,
  n.body,
  n.amount,
  n.status
FROM notification_events ne
LEFT JOIN notifications n ON n.event_id = ne.event_id
WHERE ne.event_code = 'PAYMENT_SUCCESS'
  AND ne.payment_id = 'YOUR_MILESTONE_ID_HERE'::UUID
ORDER BY ne.created_at DESC;

-- ============================================================================
-- TEST 6: Test Campaign Broadcast
-- ============================================================================
-- First, create a test campaign:
-- INSERT INTO notification_campaigns (
--   title,
--   message,
--   target_audience,
--   status,
--   created_by
-- ) VALUES (
--   'Test Campaign',
--   'This is a test notification campaign',
--   'all_users',
--   'draft',
--   (SELECT id FROM auth.users LIMIT 1)
-- ) RETURNING id;

-- Then test the RPC function:
-- SELECT notify_campaign_broadcast(
--   p_campaign_id := 'YOUR_CAMPAIGN_ID_HERE'::UUID
-- );

-- Check if notifications were created:
SELECT 
  ne.event_id,
  ne.event_code,
  ne.campaign_id,
  ne.actor_role,
  ne.processed,
  COUNT(n.notification_id) as notification_count
FROM notification_events ne
LEFT JOIN notifications n ON n.event_id = ne.event_id
WHERE ne.event_code = 'CAMPAIGN_BROADCAST'
  AND ne.campaign_id = 'YOUR_CAMPAIGN_ID_HERE'::UUID
GROUP BY ne.event_id, ne.event_code, ne.campaign_id, ne.actor_role, ne.processed
ORDER BY ne.created_at DESC;

-- ============================================================================
-- TEST 7: View Recent Notification Events
-- ============================================================================
SELECT 
  ne.event_id,
  ne.event_code,
  ne.booking_id,
  ne.order_id,
  ne.payment_id,
  ne.actor_role,
  ne.processed,
  ne.processed_at,
  ne.created_at,
  COUNT(n.notification_id) as notification_count
FROM notification_events ne
LEFT JOIN notifications n ON n.event_id = ne.event_id
GROUP BY ne.event_id, ne.event_code, ne.booking_id, ne.order_id, ne.payment_id, 
         ne.actor_role, ne.processed, ne.processed_at, ne.created_at
ORDER BY ne.created_at DESC
LIMIT 10;

-- ============================================================================
-- TEST 8: View Recent Notifications
-- ============================================================================
SELECT 
  n.notification_id,
  n.event_id,
  n.recipient_role,
  n.recipient_user_id,
  n.recipient_vendor_id,
  n.title,
  n.body,
  n.order_id,
  n.booking_id,
  n.amount,
  n.status,
  n.type,
  n.created_at,
  n.sent_at,
  n.read_at
FROM notifications n
ORDER BY n.created_at DESC
LIMIT 20;

-- ============================================================================
-- TEST 9: View Notification Logs (Push Notification Attempts)
-- ============================================================================
SELECT 
  nl.log_id,
  nl.notification_id,
  nl.channel,
  nl.status,
  nl.provider_message_id,
  nl.error_code,
  nl.error_message,
  nl.attempted_at,
  nl.retry_count,
  n.title,
  n.recipient_role
FROM notification_logs nl
JOIN notifications n ON n.notification_id = nl.notification_id
ORDER BY nl.attempted_at DESC
LIMIT 20;

-- ============================================================================
-- TEST 10: Check Notification Processing Status
-- ============================================================================
SELECT 
  event_code,
  COUNT(*) as total_events,
  COUNT(*) FILTER (WHERE processed = true) as processed_events,
  COUNT(*) FILTER (WHERE processed = false) as pending_events,
  COUNT(DISTINCT n.notification_id) as total_notifications_created
FROM notification_events ne
LEFT JOIN notifications n ON n.event_id = ne.event_id
GROUP BY event_code
ORDER BY total_events DESC;

-- ============================================================================
-- TEST 11: Test Deduplication (Run same event twice)
-- ============================================================================
-- First, call the RPC function:
-- SELECT notify_vendor_arrived(
--   p_booking_id := 'YOUR_BOOKING_ID_HERE'::UUID,
--   p_order_id := NULL
-- );

-- Then call it again immediately (should be deduplicated):
-- SELECT notify_vendor_arrived(
--   p_booking_id := 'YOUR_BOOKING_ID_HERE'::UUID,
--   p_order_id := NULL
-- );

-- Check deduplication - should only have one event:
SELECT 
  ne.event_id,
  ne.event_code,
  ne.booking_id,
  ne.dedupe_key,
  ne.processed,
  COUNT(n.notification_id) as notification_count
FROM notification_events ne
LEFT JOIN notifications n ON n.event_id = ne.event_id
WHERE ne.event_code = 'ORDER_VENDOR_ARRIVED'
  AND ne.booking_id = 'YOUR_BOOKING_ID_HERE'::UUID
GROUP BY ne.event_id, ne.event_code, ne.booking_id, ne.dedupe_key, ne.processed
ORDER BY ne.created_at DESC;

-- ============================================================================
-- TEST 12: Check for Failed Notifications
-- ============================================================================
SELECT 
  nl.log_id,
  nl.notification_id,
  nl.channel,
  nl.status,
  nl.error_code,
  nl.error_message,
  nl.retry_count,
  nl.attempted_at,
  n.title,
  n.recipient_role,
  n.recipient_user_id,
  n.recipient_vendor_id
FROM notification_logs nl
JOIN notifications n ON n.notification_id = nl.notification_id
WHERE nl.status = 'FAILED'
ORDER BY nl.attempted_at DESC
LIMIT 20;

-- ============================================================================
-- TEST 13: Get Sample Data for Testing
-- ============================================================================
-- Get a sample booking ID:
SELECT 
  b.id as booking_id,
  b.status,
  b.milestone_status,
  b.user_id,
  b.vendor_id,
  u.email as user_email,
  v.business_name as vendor_name
FROM bookings b
LEFT JOIN user_profiles u ON u.user_id = b.user_id
LEFT JOIN vendor_profiles v ON v.id = b.vendor_id
WHERE b.status != 'cancelled'
LIMIT 5;

-- Get a sample payment milestone:
SELECT 
  pm.id as milestone_id,
  pm.booking_id,
  pm.milestone_type,
  pm.status,
  pm.amount,
  b.user_id,
  b.vendor_id
FROM payment_milestones pm
JOIN bookings b ON b.id = pm.booking_id
WHERE pm.status = 'pending'
LIMIT 5;

-- Get a sample campaign:
SELECT 
  id as campaign_id,
  title,
  message,
  target_audience,
  status
FROM notification_campaigns
WHERE status = 'draft'
LIMIT 5;

-- ============================================================================
-- TEST 14: Cleanup Test Data (Optional - Use with caution!)
-- ============================================================================
-- Delete test notification events (only if you want to clean up):
-- DELETE FROM notification_events 
-- WHERE event_code = 'ORDER_VENDOR_ARRIVED' 
--   AND created_at > NOW() - INTERVAL '1 hour';

-- Delete test notifications:
-- DELETE FROM notifications 
-- WHERE created_at > NOW() - INTERVAL '1 hour'
--   AND title LIKE 'Test%';

-- ============================================================================
-- SUMMARY QUERY: Overall System Health
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
WHERE status = 'FAILED'
UNION ALL
SELECT 
  'Total Push Attempts',
  COUNT(*)::text
FROM notification_logs
WHERE channel = 'PUSH'
UNION ALL
SELECT 
  'Successful Push Attempts',
  COUNT(*)::text
FROM notification_logs
WHERE channel = 'PUSH' AND status = 'SENT'
UNION ALL
SELECT 
  'Failed Push Attempts',
  COUNT(*)::text
FROM notification_logs
WHERE channel = 'PUSH' AND status = 'FAILED';
