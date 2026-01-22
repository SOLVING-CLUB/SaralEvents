-- ============================================================================
-- FORCE FIX DUPLICATE payment_success_notification TRIGGER
-- Uses system catalogs to find and remove all instances
-- ============================================================================

-- Step 1: Query pg_trigger directly (system catalog) to see what's really there
SELECT 
  'System Catalog Check' as check_type,
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  tgenabled as enabled,
  tgisinternal as is_internal
FROM pg_trigger
WHERE tgname = 'payment_success_notification'
ORDER BY tgname, tgrelid;

-- Step 2: Get the OID of the table
DO $$
DECLARE
  v_table_oid OID;
  v_trigger_count INT;
BEGIN
  -- Get the table OID
  SELECT oid INTO v_table_oid
  FROM pg_class
  WHERE relname = 'payment_milestones'
    AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
  
  IF v_table_oid IS NULL THEN
    RAISE EXCEPTION 'Table payment_milestones not found';
  END IF;
  
  -- Count triggers on this table
  SELECT COUNT(*) INTO v_trigger_count
  FROM pg_trigger
  WHERE tgrelid = v_table_oid
    AND tgname = 'payment_success_notification'
    AND NOT tgisinternal;
  
  RAISE NOTICE 'Found % instances of payment_success_notification on payment_milestones', v_trigger_count;
  
  -- Drop ALL triggers with this name on this table
  -- Use pg_trigger to get the exact OID and drop by OID
  FOR v_trigger_count IN 
    SELECT oid
    FROM pg_trigger
    WHERE tgrelid = v_table_oid
      AND tgname = 'payment_success_notification'
      AND NOT tgisinternal
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones');
    RAISE NOTICE 'Attempted to drop trigger OID: %', v_trigger_count;
  END LOOP;
END $$;

-- Step 3: Alternative method - Drop using DROP TRIGGER (correct syntax)
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;

-- Step 4: Verify complete removal using system catalog
SELECT 
  'After Force Drop' as check_type,
  COUNT(*) as remaining_instances,
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ All instances removed'
    ELSE '⚠️ Still exists - OIDs: ' || string_agg(oid::text, ', ')
  END as status
FROM pg_trigger
WHERE tgname = 'payment_success_notification'
  AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public'))
  AND NOT tgisinternal;

-- Step 5: Also check information_schema
SELECT 
  'Information Schema Check' as check_type,
  COUNT(*) as instances,
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ Removed from information_schema'
    ELSE '⚠️ Still showing in information_schema'
  END as status
FROM information_schema.triggers
WHERE trigger_name = 'payment_success_notification'
  AND event_object_table = 'payment_milestones';

-- Step 6: Wait a moment for catalog to update
DO $$
BEGIN
  PERFORM pg_sleep(0.5);
END $$;

-- Step 7: Verify function exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'notify_payment_success'
  ) THEN
    RAISE EXCEPTION 'Function notify_payment_success does not exist. Run automated_notification_triggers.sql first.';
  END IF;
  RAISE NOTICE '✅ Function notify_payment_success exists';
END $$;

-- Step 8: Create the trigger ONCE with explicit check
DO $$
BEGIN
  -- Check using system catalog
  IF EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'payment_success_notification'
      AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public'))
      AND NOT tgisinternal
  ) THEN
    RAISE NOTICE '⚠️ Trigger still exists in system catalog, skipping creation';
  ELSE
    -- Create the trigger
    EXECUTE 'CREATE TRIGGER payment_success_notification
      AFTER INSERT OR UPDATE ON payment_milestones
      FOR EACH ROW
      WHEN (NEW.status IN (''paid'', ''held_in_escrow'', ''released''))
      EXECUTE FUNCTION notify_payment_success()';
    
    RAISE NOTICE '✅ Created payment_success_notification trigger';
  END IF;
END $$;

-- Step 9: Final verification using system catalog
SELECT 
  'Final System Catalog Check' as check_type,
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  COUNT(*) as instance_count,
  CASE 
    WHEN COUNT(*) = 1 THEN '✅ OK - Single instance'
    WHEN COUNT(*) > 1 THEN '❌ STILL DUPLICATE - ' || COUNT(*) || ' instances'
    ELSE '❌ MISSING'
  END as status
FROM pg_trigger
WHERE tgname = 'payment_success_notification'
  AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public'))
  AND NOT tgisinternal
GROUP BY tgname, tgrelid;

-- Step 10: Final verification using information_schema
SELECT 
  'Final Information Schema Check' as check_type,
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
  AND event_object_table = 'payment_milestones'
GROUP BY trigger_name, event_object_table;

-- Step 11: Overall status
SELECT 
  'Overall Trigger Status' as check_type,
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

-- Step 12: Final count
SELECT 
  'Final Count' as check_type,
  COUNT(DISTINCT trigger_name) as unique_triggers,
  COUNT(*) as total_instances,
  CASE 
    WHEN COUNT(DISTINCT trigger_name) = 3 AND COUNT(*) = 3 
    THEN '✅ PERFECT - All 3 triggers, no duplicates'
    ELSE '❌ ISSUE - unique: ' || COUNT(DISTINCT trigger_name) || ', total: ' || COUNT(*)
  END as status
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
);
