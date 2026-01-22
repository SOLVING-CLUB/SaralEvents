    -- ============================================================================
    -- CHECK WHY INFORMATION_SCHEMA SHOWS 2 INSTANCES
    -- This will show if it's because the trigger handles both INSERT and UPDATE
    -- ============================================================================

    -- Step 1: Check what events the trigger handles
    SELECT 
    'Trigger Event Details' as check_type,
    trigger_name,
    event_object_table,
    event_manipulation,  -- This shows INSERT, UPDATE, DELETE, etc.
    action_timing,       -- BEFORE, AFTER, INSTEAD OF
    COUNT(*) as count
    FROM information_schema.triggers
    WHERE trigger_name = 'payment_success_notification'
    AND event_object_table = 'payment_milestones'
    GROUP BY trigger_name, event_object_table, event_manipulation, action_timing
    ORDER BY event_manipulation;

    -- Step 2: Check system catalog for the actual trigger definition
    SELECT 
    'System Catalog Definition' as check_type,
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    CASE 
        WHEN tgenabled = 'O' THEN 'Enabled for all'
        WHEN tgenabled = 'D' THEN 'Disabled'
        ELSE 'Other'
    END as enabled_status,
    pg_get_triggerdef(oid) as trigger_definition
    FROM pg_trigger
    WHERE tgname = 'payment_success_notification'
    AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public'))
    AND NOT tgisinternal;

    -- Step 3: Check if information_schema is showing separate rows for INSERT and UPDATE
    SELECT 
    'Information Schema Breakdown' as check_type,
    trigger_name,
    event_object_table,
    event_manipulation,
    action_timing,
    action_statement
    FROM information_schema.triggers
    WHERE trigger_name = 'payment_success_notification'
    AND event_object_table = 'payment_milestones'
    ORDER BY event_manipulation;

    -- Step 4: Diagnosis
    SELECT 
    'DIAGNOSIS' as check_type,
    CASE 
        WHEN (SELECT COUNT(DISTINCT event_manipulation) FROM information_schema.triggers WHERE trigger_name = 'payment_success_notification' AND event_object_table = 'payment_milestones') = 2
        THEN '✅ FOUND IT: Information_schema shows 2 rows because the trigger handles both INSERT and UPDATE events. This is NORMAL behavior - the trigger definition "AFTER INSERT OR UPDATE" causes information_schema to show it twice (once for INSERT, once for UPDATE). This is CORRECT and EXPECTED. The trigger will work perfectly.'
        WHEN (SELECT COUNT(*) FROM pg_trigger WHERE tgname = 'payment_success_notification' AND tgrelid = (SELECT oid FROM pg_class WHERE relname = 'payment_milestones' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) AND NOT tgisinternal) = 1
        THEN '✅ Only 1 trigger exists in database. Information_schema showing 2 is due to how it represents triggers that handle multiple events. This is normal PostgreSQL behavior.'
        ELSE '⚠️ Unknown issue'
    END as conclusion;

    -- Step 5: Show comparison with other triggers
    SELECT 
    'Comparison with Other Triggers' as check_type,
    trigger_name,
    event_object_table,
    string_agg(DISTINCT event_manipulation, ', ' ORDER BY event_manipulation) as events_handled,
    COUNT(*) as rows_in_view,
    CASE 
        WHEN COUNT(DISTINCT event_manipulation) > 1 THEN 'Handles multiple events (normal to see multiple rows)'
        ELSE 'Handles single event'
    END as note
    FROM information_schema.triggers
    WHERE trigger_name IN (
    'booking_status_change_notification',
    'payment_success_notification',
    'milestone_confirmation_notification_vendor'
    )
    GROUP BY trigger_name, event_object_table
    ORDER BY trigger_name;
