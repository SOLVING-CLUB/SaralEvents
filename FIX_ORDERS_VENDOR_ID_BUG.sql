-- ============================================================================
-- FIX: Orders Table vendor_id Bug in Notification System
-- ============================================================================
-- The notification system tries to access o.vendor_id from orders table,
-- but orders table doesn't have vendor_id. Vendor info comes from bookings.
-- 
-- SOLUTION: Update all queries to get vendor_id from bookings table instead.
-- ============================================================================

-- This is a comprehensive fix. You need to re-run STEP_03B_COMPLETE_REMAINING_NOTIFICATION_RULES.sql
-- after applying this fix, OR manually update the function.

-- The fix pattern:
-- OLD: SELECT o.user_id, o.vendor_id FROM orders o WHERE o.id = p_order_id;
-- NEW: SELECT o.user_id, b.vendor_id FROM orders o JOIN bookings b ON b.id = o.booking_id WHERE o.id = p_order_id;

-- OR if p_booking_id is provided:
-- SELECT b.user_id, b.vendor_id FROM bookings b WHERE b.id = p_booking_id;

-- I've already fixed ORDER_VENDOR_ARRIVED in STEP_03B_COMPLETE_REMAINING_NOTIFICATION_RULES.sql
-- You need to re-run that entire file to apply all fixes.

-- Quick test to verify orders table structure:
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'orders'
  AND column_name LIKE '%vendor%'
ORDER BY column_name;

-- Check if orders has booking_id:
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'orders'
  AND column_name LIKE '%booking%'
ORDER BY column_name;
