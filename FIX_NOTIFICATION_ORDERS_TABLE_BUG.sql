-- ============================================================================
-- FIX: Notification System - Orders Table Bug
-- ============================================================================
-- The notification system was trying to access o.vendor_id from orders table,
-- but orders table doesn't have vendor_id. Vendor info comes from bookings.
-- This script fixes all the queries in process_notification_event function.
-- ============================================================================

-- This is a reference file showing what needs to be fixed.
-- The actual fix is in STEP_03B_COMPLETE_REMAINING_NOTIFICATION_RULES.sql
-- Run that file again after this fix is applied.

-- Summary of changes needed:
-- 1. ORDER_VENDOR_ARRIVED: Get vendor_id from bookings, not orders
-- 2. ORDER_USER_CONFIRM_ARRIVAL: Get vendor_id from bookings, not orders  
-- 3. ORDER_VENDOR_SETUP_COMPLETED: Get vendor_id from bookings, not orders
-- 4. ORDER_USER_CONFIRM_SETUP: Get vendor_id from bookings, not orders
-- 5. ORDER_VENDOR_COMPLETED: Get vendor_id from bookings, not orders
-- 6. ORDER_USER_CANCELLED: Get vendor_id from bookings, not orders
-- 7. ORDER_VENDOR_CANCELLED: Get vendor_id from bookings, not orders
-- 8. ORDER_PAYMENT_SUCCESS: Get vendor_id from bookings, not orders
-- 9. ORDER_VENDOR_DECISION: Get vendor_id from bookings, not orders
-- 10. PAYMENT_ANY_STAGE: Get vendor_id from bookings via payment_milestones, not orders

-- The pattern should be:
-- - If p_booking_id is provided, use bookings table directly
-- - If p_order_id is provided, join orders -> bookings -> vendor_profiles
-- - Never access o.vendor_id directly
