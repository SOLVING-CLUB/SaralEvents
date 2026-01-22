-- Drop all notification triggers before recreating them
-- Run this first if you get "trigger already exists" errors

-- Booking status triggers
DROP TRIGGER IF EXISTS booking_status_change_notification ON bookings;
DROP TRIGGER IF EXISTS booking_status_notification_user ON bookings;
DROP TRIGGER IF EXISTS booking_status_notification_vendor ON bookings;
DROP TRIGGER IF EXISTS booking_confirmation_notification ON bookings;
DROP TRIGGER IF EXISTS milestone_confirmation_notification_vendor ON bookings;

-- Payment triggers
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;

-- Refund triggers
DROP TRIGGER IF EXISTS refund_initiated_notification ON refunds;
DROP TRIGGER IF EXISTS refund_completed_notification ON refunds;

-- Cart triggers
DROP TRIGGER IF EXISTS cart_abandonment_notification ON cart_items;

-- Order triggers (if they exist)
DROP TRIGGER IF EXISTS order_status_notification_user ON orders;
DROP TRIGGER IF EXISTS order_status_notification ON orders;
DROP TRIGGER IF EXISTS new_order_notification_vendor ON orders;

-- Drop functions (optional - they will be recreated)
DROP FUNCTION IF EXISTS notify_booking_status_change() CASCADE;
DROP FUNCTION IF EXISTS notify_payment_success() CASCADE;
DROP FUNCTION IF EXISTS notify_vendor_milestone_confirmations() CASCADE;
DROP FUNCTION IF EXISTS notify_refund_initiated() CASCADE;
DROP FUNCTION IF EXISTS notify_refund_completed() CASCADE;
DROP FUNCTION IF EXISTS notify_cart_abandonment() CASCADE;
