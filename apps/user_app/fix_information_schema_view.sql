-- ============================================================================
-- FIX INFORMATION_SCHEMA VIEW ARTIFACT
-- Recreate the trigger in a way that won't cause information_schema to show duplicates
-- ============================================================================

-- Step 1: Check current state in information_schema
SELECT 
  'Before Fix' as check_type,
  trigger_name,
  event_object_table,
  trigger_schema,
  action_timing,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'payment_success_notification'
  AND event_object_table = 'payment_milestones'
ORDER BY trigger_schema, trigger_name;

-- Step 2: Completely remove the trigger (including all metadata)
DO $$
DECLARE
  v_trigger_oid OID;
BEGIN
  -- Get the trigger OID
  SELECT oid INTO v_trigger_oid
  FROM pg_trigger
  WHERE tgname = 'payment_success_notification'
    AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public'))
    AND NOT tgisinternal
  LIMIT 1;
  
  IF v_trigger_oid IS NOT NULL THEN
    -- Drop by OID to ensure complete removal
    EXECUTE format('DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones CASCADE');
    RAISE NOTICE 'Dropped trigger with OID: %', v_trigger_oid;
  END IF;
END $$;

-- Step 3: Wait for catalog to update
DO $$
BEGIN
  PERFORM pg_sleep(1);
END $$;

-- Step 4: Verify it's completely gone from both views
SELECT 
  'After Drop - System Catalog' as check_type,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 0 THEN '✅ Removed' ELSE '⚠️ Still exists' END as status
FROM pg_trigger
WHERE tgname = 'payment_success_notification'
  AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public'))
  AND NOT tgisinternal;

SELECT 
  'After Drop - Information Schema' as check_type,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 0 THEN '✅ Removed' ELSE '⚠️ Still exists' END as status
FROM information_schema.triggers
WHERE trigger_name = 'payment_success_notification'
  AND event_object_table = 'payment_milestones';

-- Step 5: Verify function exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'notify_payment_success'
  ) THEN
    RAISE EXCEPTION 'Function notify_payment_success does not exist';
  END IF;
END $$;

-- Step 6: Recreate the trigger with explicit, clean definition
-- Using a simple, standard CREATE TRIGGER statement
CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
  EXECUTE FUNCTION notify_payment_success();

-- Step 7: Wait for catalog to update
DO $$
BEGIN
  PERFORM pg_sleep(1);
END $$;

-- Step 8: Check system catalog (should show 1)
SELECT 
  'System Catalog (Real)' as check_type,
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  COUNT(*) as count,
  CASE WHEN COUNT(*) = 1 THEN '✅ Correct (1 instance)' ELSE '❌ Issue' END as status
FROM pg_trigger
WHERE tgname = 'payment_success_notification'
  AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public'))
  AND NOT tgisinternal
GROUP BY tgname, tgrelid;

-- Step 9: Check information_schema (hopefully shows 1 now)
SELECT 
  'Information Schema (View)' as check_type,
  trigger_name,
  event_object_table,
  COUNT(*) as count,
  CASE 
    WHEN COUNT(*) = 1 THEN '✅ Fixed - Now shows 1'
    WHEN COUNT(*) > 1 THEN '⚠️ Still shows ' || COUNT(*) || ' (view artifact persists)'
    ELSE '❌ Not showing'
  END as status
FROM information_schema.triggers
WHERE trigger_name = 'payment_success_notification'
  AND event_object_table = 'payment_milestones'
GROUP BY trigger_name, event_object_table;

-- Step 10: Detailed information_schema check
SELECT 
  'Information Schema Details' as check_type,
  trigger_name,
  event_object_table,
  trigger_schema,
  action_timing,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'payment_success_notification'
  AND event_object_table = 'payment_milestones'
ORDER BY trigger_schema, trigger_name;

-- Step 11: Final verification - All triggers
SELECT 
  'All Triggers - System Catalog' as check_type,
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  COUNT(*) as actual_count
FROM pg_trigger
WHERE tgname IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
)
  AND NOT tgisinternal
GROUP BY tgname, tgrelid
ORDER BY tgname;

-- Step 12: Final verification - Information Schema
SELECT 
  'All Triggers - Information Schema' as check_type,
  trigger_name,
  event_object_table,
  COUNT(*) as view_count
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
)
GROUP BY trigger_name, event_object_table
ORDER BY trigger_name;
