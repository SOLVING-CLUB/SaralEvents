-- ============================================================================
-- REMOVE ALL DUPLICATE TRIGGERS - AGGRESSIVE CLEANUP
-- This will completely remove all notification triggers and recreate them cleanly
-- ============================================================================

-- Step 1: Drop ALL notification triggers (including any duplicates)
DO $$
DECLARE
  r RECORD;
BEGIN
  -- Drop all triggers that might exist
  FOR r IN 
    SELECT trigger_name, event_object_table
    FROM information_schema.triggers
    WHERE trigger_name IN (
      'booking_status_change_notification',
      'booking_status_notification_user',
      'booking_status_notification_vendor',
      'payment_success_notification',
      'milestone_confirmation_notification_vendor',
      'order_status_notification',
      'order_status_notification_user',
      'booking_confirmation_notification'
    )
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I', r.trigger_name, r.event_object_table);
    RAISE NOTICE 'Dropped trigger: % on %', r.trigger_name, r.event_object_table;
  END LOOP;
END $$;

-- Step 2: Verify all triggers are dropped
SELECT 
  'After Cleanup' as check_type,
  COUNT(*) as remaining_triggers,
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ All triggers removed'
    ELSE '⚠️ Some triggers still exist: ' || string_agg(trigger_name, ', ')
  END as status
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
);

-- Step 3: Verify functions exist before creating triggers
SELECT 
  'Function Verification' as check_type,
  routine_name,
  CASE WHEN routine_name IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING - Run automated_notification_triggers.sql first' END as status
FROM information_schema.routines
WHERE routine_name IN (
  'notify_booking_status_change',
  'notify_payment_success',
  'notify_vendor_milestone_confirmations'
)
ORDER BY routine_name;

-- Step 4: Create triggers one by one (ensuring no duplicates)

-- 4a: booking_status_change_notification
CREATE TRIGGER booking_status_change_notification
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_booking_status_change();

-- 4b: payment_success_notification
CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
  EXECUTE FUNCTION notify_payment_success();

-- 4c: milestone_confirmation_notification_vendor
CREATE TRIGGER milestone_confirmation_notification_vendor
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (
    OLD.milestone_status IS DISTINCT FROM NEW.milestone_status
    AND NEW.milestone_status IN ('arrival_confirmed', 'setup_confirmed')
  )
  EXECUTE FUNCTION notify_vendor_milestone_confirmations();

-- Step 5: Final verification - should be exactly 3 triggers
SELECT 
  'Final Status' as check_type,
  trigger_name,
  event_object_table,
  '✅ CREATED' as status
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
)
ORDER BY trigger_name, event_object_table;

-- Step 6: Count verification
SELECT 
  'Final Count' as check_type,
  COUNT(DISTINCT trigger_name) as unique_triggers,
  COUNT(*) as total_instances,
  CASE 
    WHEN COUNT(DISTINCT trigger_name) = 3 AND COUNT(*) = 3 
    THEN '✅ PERFECT - All 3 triggers exist, no duplicates'
    WHEN COUNT(*) > COUNT(DISTINCT trigger_name)
    THEN '❌ STILL HAS DUPLICATES - Check which trigger appears multiple times above'
    WHEN COUNT(*) < 3
    THEN '❌ MISSING TRIGGERS - Some triggers were not created'
    ELSE '⚠️ UNEXPECTED - Check results above'
  END as status
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
);

-- Step 7: Show detailed breakdown
SELECT 
  trigger_name,
  event_object_table,
  COUNT(*) as instance_count,
  CASE 
    WHEN COUNT(*) > 1 THEN '❌ DUPLICATE - This trigger appears ' || COUNT(*) || ' times'
    ELSE '✅ OK'
  END as status
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
)
GROUP BY trigger_name, event_object_table
ORDER BY instance_count DESC, trigger_name;
