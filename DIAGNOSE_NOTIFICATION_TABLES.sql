-- ============================================================================
-- DIAGNOSE NOTIFICATION TABLES
-- ============================================================================
-- Run this first to check if tables and columns exist correctly
-- ============================================================================

-- Check if tables exist
SELECT 
  'Tables' as check_type,
  table_name,
  CASE 
    WHEN table_name IN ('notification_events', 'notifications', 'notification_logs') 
    THEN '✅ Exists'
    ELSE '❌ Missing'
  END as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('notification_events', 'notifications', 'notification_logs')
ORDER BY table_name;

-- Check notification_events columns
SELECT 
  'notification_events columns' as check_type,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notification_events'
ORDER BY ordinal_position;

-- Check notifications columns
SELECT 
  'notifications columns' as check_type,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifications'
ORDER BY ordinal_position;

-- Check notification_logs columns
SELECT 
  'notification_logs columns' as check_type,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notification_logs'
ORDER BY ordinal_position;

-- If notifications table doesn't exist or is missing columns, run:
-- STEP_02_CREATE_NOTIFICATION_TABLES.sql
