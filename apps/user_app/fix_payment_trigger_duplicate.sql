-- ============================================================================
-- FIX DUPLICATE payment_success_notification TRIGGER
-- This specifically targets the duplicate payment trigger
-- ============================================================================

-- Step 1: Show current state
SELECT 
  'Current State' as check_type,
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'payment_success_notification'
ORDER BY event_object_table;

-- Step 2: Drop ALL instances of payment_success_notification
-- Use CASCADE to ensure all dependencies are removed
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT DISTINCT event_object_table
    FROM information_schema.triggers
    WHERE trigger_name = 'payment_success_notification'
  LOOP
    -- Try dropping with CASCADE first
    BEGIN
      EXECUTE format('DROP TRIGGER IF EXISTS payment_success_notification ON %I CASCADE', r.event_object_table);
      RAISE NOTICE 'Dropped payment_success_notification from %', r.event_object_table;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Error dropping trigger from %: %', r.event_object_table, SQLERRM;
    END;
    
    -- Also try without CASCADE
    BEGIN
      EXECUTE format('DROP TRIGGER payment_success_notification ON %I', r.event_object_table);
    EXCEPTION
      WHEN undefined_object THEN
        NULL; -- Trigger doesn't exist, that's fine
      WHEN OTHERS THEN
        RAISE NOTICE 'Error (second attempt) dropping trigger from %: %', r.event_object_table, SQLERRM;
    END;
  END LOOP;
END $$;

-- Step 3: Verify it's completely removed
SELECT 
  'After Drop' as check_type,
  COUNT(*) as remaining_instances,
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ All instances removed'
    ELSE '⚠️ Still exists: ' || string_agg(event_object_table::text, ', ')
  END as status
FROM information_schema.triggers
WHERE trigger_name = 'payment_success_notification';

-- Step 4: Verify the function exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'notify_payment_success'
  ) THEN
    RAISE EXCEPTION 'Function notify_payment_success does not exist. Please run automated_notification_triggers.sql first.';
  END IF;
  RAISE NOTICE '✅ Function notify_payment_success exists';
END $$;

-- Step 5: Create the trigger ONCE (with explicit check to prevent duplicates)
DO $$
BEGIN
  -- Check if trigger already exists
  IF EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE trigger_name = 'payment_success_notification'
      AND event_object_table = 'payment_milestones'
  ) THEN
    RAISE NOTICE '⚠️ Trigger already exists, skipping creation';
  ELSE
    -- Create the trigger
    CREATE TRIGGER payment_success_notification
      AFTER INSERT OR UPDATE ON payment_milestones
      FOR EACH ROW
      WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
      EXECUTE FUNCTION notify_payment_success();
    
    RAISE NOTICE '✅ Created payment_success_notification trigger';
  END IF;
END $$;

-- Step 6: Final verification
SELECT 
  'Final Verification' as check_type,
  trigger_name,
  event_object_table,
  COUNT(*) as instance_count,
  CASE 
    WHEN COUNT(*) = 1 THEN '✅ OK - Single instance'
    WHEN COUNT(*) > 1 THEN '❌ STILL DUPLICATE - ' || COUNT(*) || ' instances'
    ELSE '❌ MISSING'
  END as status
FROM information_schema.triggers
WHERE trigger_name = 'payment_success_notification'
GROUP BY trigger_name, event_object_table;

-- Step 7: Overall trigger status
SELECT 
  'Overall Status' as check_type,
  trigger_name,
  event_object_table,
  '✅ EXISTS' as status
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
)
ORDER BY trigger_name, event_object_table;

-- Step 8: Final count
SELECT 
  'Final Count' as check_type,
  COUNT(DISTINCT trigger_name) as unique_triggers,
  COUNT(*) as total_instances,
  CASE 
    WHEN COUNT(DISTINCT trigger_name) = 3 AND COUNT(*) = 3 
    THEN '✅ PERFECT - All 3 triggers, no duplicates'
    ELSE '❌ ISSUE - Check above for details'
  END as status
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
);
