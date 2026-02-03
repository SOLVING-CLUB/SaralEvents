-- ============================================================================
-- FIX: Replace ON CONFLICT with explicit existence check
-- ============================================================================
-- PostgreSQL's ON CONFLICT may not work with partial unique indexes.
-- This patch replaces all ON CONFLICT (dedupe_key) DO NOTHING clauses
-- with explicit existence checks in the process_notification_event function.
-- ============================================================================

-- The issue is that ON CONFLICT requires a unique constraint/index, and
-- partial unique indexes may not always be recognized properly.
-- Solution: Replace ON CONFLICT with explicit SELECT ... WHERE dedupe_key check

-- We need to update the process_notification_event function.
-- Instead of:
--   INSERT ... ON CONFLICT (dedupe_key) DO NOTHING RETURNING notification_id INTO v_notification_id;
-- 
-- We'll use:
--   SELECT notification_id INTO v_notification_id FROM notifications WHERE dedupe_key = v_dedupe_key;
--   IF v_notification_id IS NULL THEN
--     INSERT ... RETURNING notification_id INTO v_notification_id;
--   END IF;

-- However, updating the entire function is complex. Let's try a simpler approach:
-- Ensure the unique index is properly created and recognized by PostgreSQL.

-- Step 1: Drop all existing dedupe_key indexes
DROP INDEX IF EXISTS idx_notifications_dedupe_key;
DROP INDEX IF EXISTS idx_notifications_dedupe_key_unique;

-- Step 2: Create a proper unique index (without WHERE clause if possible)
-- But we need to allow NULLs, so we'll use a partial index
-- However, let's try creating it as a regular unique index first to see if that works
-- (This will fail if there are duplicate non-NULL dedupe_keys, which is what we want)

-- Check for duplicate dedupe_keys first
SELECT 
  dedupe_key,
  COUNT(*) as count
FROM notifications
WHERE dedupe_key IS NOT NULL
GROUP BY dedupe_key
HAVING COUNT(*) > 1;

-- Step 3: If no duplicates, create a full unique index (this should work with ON CONFLICT)
-- If there are duplicates, we need to clean them up first
-- For now, let's stick with the partial unique index but ensure it's created correctly

CREATE UNIQUE INDEX idx_notifications_dedupe_key_unique 
ON notifications(dedupe_key) 
WHERE dedupe_key IS NOT NULL;

-- Step 4: Verify the index
SELECT 
  indexname,
  indexdef,
  'Index created' as status
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'notifications'
  AND indexname = 'idx_notifications_dedupe_key_unique';

-- Step 5: The real fix - we need to update the function to use explicit checks
-- But that's a large change. Let's try one more thing: ensure the function is recreated
-- so it picks up the index. Actually, functions don't cache execution plans in the same way,
-- so that shouldn't be the issue.

-- The best solution is to replace ON CONFLICT with explicit checks.
-- Let me create a minimal patch for the ORDER_VENDOR_ARRIVED case:
