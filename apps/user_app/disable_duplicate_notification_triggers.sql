-- ============================================================================
-- DISABLE DUPLICATE NOTIFICATION TRIGGERS
-- ============================================================================
-- This script disables database triggers that send duplicate notifications
-- App code now handles notifications with more specific messages
-- Run this in your Supabase SQL Editor

-- Disable payment success trigger (app code sends more specific milestone notifications)
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;

-- Disable booking confirmation trigger (app code sends when vendor accepts)
DROP TRIGGER IF EXISTS booking_confirmation_notification ON bookings;

-- Note: Keep booking_status_change_notification trigger for status changes
-- (completed, cancelled) as these are not sent from app code

-- Verify triggers are disabled
SELECT 
  trigger_name, 
  event_object_table, 
  action_timing, 
  event_manipulation
FROM information_schema.triggers
WHERE trigger_name IN (
  'payment_success_notification',
  'booking_confirmation_notification'
)
AND event_object_schema = 'public';

-- Should return 0 rows if triggers are successfully disabled
