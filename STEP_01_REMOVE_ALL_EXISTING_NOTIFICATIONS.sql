-- ============================================================================
-- STEP 1: REMOVE ALL EXISTING NOTIFICATION LOGIC
-- ============================================================================
-- This query removes ALL existing notification triggers and functions
-- Run this FIRST before implementing the new notification system
-- ============================================================================

-- Drop ALL notification triggers
DROP TRIGGER IF EXISTS booking_status_change_notification ON bookings;
DROP TRIGGER IF EXISTS booking_status_notification_user ON bookings;
DROP TRIGGER IF EXISTS booking_status_notification_vendor ON bookings;
DROP TRIGGER IF EXISTS booking_confirmation_notification ON bookings;
DROP TRIGGER IF EXISTS milestone_confirmation_notification_vendor ON bookings;
DROP TRIGGER IF EXISTS new_booking_notification ON bookings;
DROP TRIGGER IF EXISTS order_status_notification_user ON orders;
DROP TRIGGER IF EXISTS order_status_notification ON orders;
DROP TRIGGER IF EXISTS new_order_notification_vendor ON orders;
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;
DROP TRIGGER IF EXISTS refund_initiated_notification ON refunds;
DROP TRIGGER IF EXISTS refund_completed_notification ON refunds;
DROP TRIGGER IF EXISTS wallet_payment_released_notification ON wallet_transactions;
DROP TRIGGER IF EXISTS withdrawal_status_notification ON withdrawal_requests;
DROP TRIGGER IF EXISTS cart_abandonment_notification ON cart_items;
DROP TRIGGER IF EXISTS test_simple_payment_trigger ON payment_milestones;

-- Drop ALL notification functions
DROP FUNCTION IF EXISTS notify_booking_status_change() CASCADE;
DROP FUNCTION IF EXISTS notify_payment_success() CASCADE;
DROP FUNCTION IF EXISTS notify_vendor_milestone_confirmations() CASCADE;
DROP FUNCTION IF EXISTS notify_refund_initiated() CASCADE;
DROP FUNCTION IF EXISTS notify_refund_completed() CASCADE;
DROP FUNCTION IF EXISTS notify_cart_abandonment() CASCADE;
DROP FUNCTION IF EXISTS notify_new_booking() CASCADE;
DROP FUNCTION IF EXISTS notify_order_status_change() CASCADE;
DROP FUNCTION IF EXISTS notify_wallet_payment_released() CASCADE;
DROP FUNCTION IF EXISTS notify_withdrawal_status() CASCADE;
DROP FUNCTION IF EXISTS notify_booking_confirmation() CASCADE;
DROP FUNCTION IF EXISTS notify_order_cancellation() CASCADE;
DROP FUNCTION IF EXISTS notify_vendor_new_order() CASCADE;
DROP FUNCTION IF EXISTS notify_vendor_payment_released() CASCADE;
DROP FUNCTION IF EXISTS notify_vendor_withdrawal_status() CASCADE;

-- Verify removal (should return 0 rows)
SELECT 
  'Verification: Remaining Notification Triggers' as check_type,
  trigger_name,
  event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE '%notification%'
ORDER BY event_object_table, trigger_name;

-- Verify removal of functions (should return 0 rows)
SELECT 
  'Verification: Remaining Notification Functions' as check_type,
  routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%notify%'
ORDER BY routine_name;
