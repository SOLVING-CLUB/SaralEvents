-- ============================================================================
-- FIX MISSING AND DUPLICATE TRIGGERS
-- This will create the missing booking_status_change_notification trigger
-- and remove duplicate payment_success_notification triggers
-- ============================================================================

-- Step 1: Drop ALL existing notification triggers to start fresh
DROP TRIGGER IF EXISTS booking_status_change_notification ON bookings;
DROP TRIGGER IF EXISTS booking_status_notification_user ON bookings;
DROP TRIGGER IF EXISTS booking_status_notification_vendor ON bookings;
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;
DROP TRIGGER IF EXISTS milestone_confirmation_notification_vendor ON bookings;

-- Step 2: Verify functions exist (they should from automated_notification_triggers.sql)
SELECT 
  'Function Check' as check_type,
  routine_name,
  CASE WHEN routine_name IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM information_schema.routines
WHERE routine_name IN (
  'notify_booking_status_change',
  'notify_payment_success',
  'notify_vendor_milestone_confirmations'
)
ORDER BY routine_name;

-- Step 3: Create booking_status_change_notification trigger
CREATE TRIGGER booking_status_change_notification
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_booking_status_change();

-- Step 4: Create payment_success_notification trigger (single instance)
CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
  EXECUTE FUNCTION notify_payment_success();

-- Step 5: Create milestone_confirmation_notification_vendor trigger (if not exists)
CREATE TRIGGER milestone_confirmation_notification_vendor
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (
    OLD.milestone_status IS DISTINCT FROM NEW.milestone_status
    AND NEW.milestone_status IN ('arrival_confirmed', 'setup_confirmed')
  )
  EXECUTE FUNCTION notify_vendor_milestone_confirmations();

-- Step 6: Verify all triggers are created correctly
SELECT 
  'Final Trigger Status' as check_type,
  trigger_name,
  event_object_table,
  CASE WHEN trigger_name IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
)
ORDER BY trigger_name, event_object_table;

-- Step 7: Count triggers (should be exactly 3)
SELECT 
  'Trigger Count Verification' as check_type,
  COUNT(DISTINCT trigger_name) as unique_triggers,
  COUNT(*) as total_instances,
  CASE 
    WHEN COUNT(DISTINCT trigger_name) = 3 AND COUNT(*) = 3 
    THEN '✅ Perfect - All 3 triggers exist, no duplicates'
    WHEN COUNT(*) > COUNT(DISTINCT trigger_name)
    THEN '⚠️ Duplicates detected - check above'
    ELSE '❌ Missing triggers - check above'
  END as status
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
);
