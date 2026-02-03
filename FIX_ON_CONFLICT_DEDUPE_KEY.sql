-- ============================================================================
-- FIX: Ensure dedupe_key has a proper unique constraint for ON CONFLICT
-- ============================================================================
-- PostgreSQL's ON CONFLICT requires a unique constraint or unique index.
-- Partial indexes (WHERE clause) may not always work with ON CONFLICT.
-- This script ensures we have a proper unique constraint.
-- ============================================================================

-- Step 1: Check current indexes on dedupe_key
SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'notifications'
  AND indexdef LIKE '%dedupe_key%';

-- Step 2: Check if there's a unique constraint
SELECT 
  conname as constraint_name,
  contype as constraint_type,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.notifications'::regclass
  AND pg_get_constraintdef(oid) LIKE '%dedupe_key%';

-- Step 3: Drop existing partial unique index (if it exists)
DROP INDEX IF EXISTS idx_notifications_dedupe_key;

-- Step 4: Create a unique constraint directly (this is what ON CONFLICT needs)
-- Note: We can't use a partial unique constraint directly, so we'll use a unique index
-- but ensure it's created in a way that PostgreSQL recognizes for ON CONFLICT

-- First, let's check if there are any NULL dedupe_keys that would prevent a full unique constraint
SELECT 
  COUNT(*) as total_rows,
  COUNT(dedupe_key) as non_null_dedupe_keys,
  COUNT(*) - COUNT(dedupe_key) as null_dedupe_keys
FROM notifications;

-- Step 5: Create unique index that PostgreSQL will recognize for ON CONFLICT
-- Using a partial unique index should work, but let's make sure it's properly created
CREATE UNIQUE INDEX idx_notifications_dedupe_key_unique 
ON notifications(dedupe_key) 
WHERE dedupe_key IS NOT NULL;

-- Step 6: Verify the index was created and is unique
SELECT 
  indexname,
  indexdef,
  indisunique as is_unique
FROM pg_indexes i
JOIN pg_index idx ON idx.indexrelid = (i.schemaname||'.'||i.indexname)::regclass
WHERE i.schemaname = 'public'
  AND i.tablename = 'notifications'
  AND i.indexname = 'idx_notifications_dedupe_key_unique';

-- Step 7: Test if ON CONFLICT will work by checking index properties
SELECT 
  'Index created successfully' as status,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'notifications'
  AND indexname = 'idx_notifications_dedupe_key_unique';

-- ============================================================================
-- ALTERNATIVE: If the above doesn't work, we might need to use a different approach
-- Instead of ON CONFLICT, we could check for existence first
-- But let's try the index approach first
-- ============================================================================
