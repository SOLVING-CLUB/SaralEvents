-- ============================================================================
-- CHECK NOTIFICATIONS TABLE STRUCTURE
-- ============================================================================
-- Run this to see what columns the notifications table actually has
-- ============================================================================

-- Check if notifications table exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'notifications'
    )
    THEN '✅ notifications table EXISTS'
    ELSE '❌ notifications table DOES NOT EXIST - Run STEP_02_CREATE_NOTIFICATION_TABLES.sql'
  END as table_status;

-- If table exists, show all its columns
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifications'
ORDER BY ordinal_position;

-- Check what the primary key column is called
SELECT 
  tc.constraint_name,
  kcu.column_name,
  tc.constraint_type
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema = 'public'
  AND tc.table_name = 'notifications'
  AND tc.constraint_type = 'PRIMARY KEY';

-- If notifications table doesn't exist or is missing columns, 
-- the primary key might be called 'id' instead of 'notification_id'
-- Check for any column that looks like an ID:
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifications'
  AND (column_name LIKE '%id%' OR column_name LIKE '%_id')
ORDER BY column_name;
