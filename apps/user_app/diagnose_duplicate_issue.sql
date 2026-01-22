-- ============================================================================
-- DIAGNOSE DUPLICATE TRIGGER ISSUE
-- Determine if this is a real duplicate or an information_schema view issue
-- ============================================================================

-- Step 1: Check system catalog (pg_trigger) - THE SOURCE OF TRUTH
SELECT 
  'System Catalog (pg_trigger) - REAL DATA' as source,
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  tgenabled as enabled,
  tgisinternal as is_internal,
  oid as trigger_oid
FROM pg_trigger
WHERE tgname = 'payment_success_notification'
  AND NOT tgisinternal
ORDER BY oid;

-- Step 2: Count in system catalog
SELECT 
  'System Catalog Count' as check_type,
  COUNT(*) as actual_instances,
  CASE 
    WHEN COUNT(*) = 1 THEN '✅ Only 1 trigger exists (real)'
    WHEN COUNT(*) > 1 THEN '❌ Multiple triggers exist (real duplicates)'
    ELSE '❌ No trigger exists'
  END as status
FROM pg_trigger
WHERE tgname = 'payment_success_notification'
  AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public'))
  AND NOT tgisinternal;

-- Step 3: Check information_schema view
SELECT 
  'Information Schema View' as source,
  trigger_name,
  event_object_table,
  event_object_schema,
  action_timing,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'payment_success_notification'
  AND event_object_table = 'payment_milestones'
ORDER BY trigger_name, event_object_schema;

-- Step 4: Count in information_schema
SELECT 
  'Information Schema Count' as check_type,
  COUNT(*) as view_instances,
  CASE 
    WHEN COUNT(*) = 1 THEN '✅ Shows 1 instance'
    WHEN COUNT(*) > 1 THEN '⚠️ Shows ' || COUNT(*) || ' instances (might be view issue)'
    ELSE '❌ Not showing'
  END as status
FROM information_schema.triggers
WHERE trigger_name = 'payment_success_notification'
  AND event_object_table = 'payment_milestones';

-- Step 5: Check if trigger exists in multiple schemas
SELECT 
  'Schema Check' as check_type,
  nspname as schema_name,
  COUNT(*) as trigger_count
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE t.tgname = 'payment_success_notification'
  AND NOT t.tgisinternal
GROUP BY nspname;

-- Step 6: Compare system catalog vs information_schema
SELECT 
  'Comparison' as check_type,
  (SELECT COUNT(*) FROM pg_trigger WHERE tgname = 'payment_success_notification' AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) AND NOT tgisinternal) as system_catalog_count,
  (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_name = 'payment_success_notification' AND event_object_table = 'payment_milestones') as information_schema_count,
  CASE 
    WHEN (SELECT COUNT(*) FROM pg_trigger WHERE tgname = 'payment_success_notification' AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) AND NOT tgisinternal) = 1
      AND (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_name = 'payment_success_notification' AND event_object_table = 'payment_milestones') > 1
    THEN '✅ REAL: Only 1 trigger exists. Information_schema is showing duplicate (view issue)'
    WHEN (SELECT COUNT(*) FROM pg_trigger WHERE tgname = 'payment_success_notification' AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) AND NOT tgisinternal) > 1
    THEN '❌ REAL: Multiple triggers exist in database (actual duplicates)'
    ELSE '⚠️ UNKNOWN: Check counts above'
  END as diagnosis;

-- Step 7: Check all notification triggers in system catalog
SELECT 
  'All Notification Triggers (System Catalog)' as check_type,
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  COUNT(*) as instance_count,
  string_agg(oid::text, ', ') as trigger_oids
FROM pg_trigger
WHERE tgname IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
)
  AND NOT tgisinternal
GROUP BY tgname, tgrelid
ORDER BY tgname;

-- Step 8: Final diagnosis
SELECT 
  'DIAGNOSIS' as check_type,
  CASE 
    WHEN (SELECT COUNT(*) FROM pg_trigger WHERE tgname = 'payment_success_notification' AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) AND NOT tgisinternal) = 1
    THEN '✅ PROBLEM IS IN SUPABASE/INFORMATION_SCHEMA VIEW - Only 1 trigger actually exists. The duplicate is a view artifact. You can safely ignore it.'
    WHEN (SELECT COUNT(*) FROM pg_trigger WHERE tgname = 'payment_success_notification' AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) AND NOT tgisinternal) > 1
    THEN '❌ PROBLEM IS IN DATABASE - Multiple triggers actually exist. Need to remove duplicates.'
    ELSE '⚠️ UNKNOWN - Check results above'
  END as conclusion;
