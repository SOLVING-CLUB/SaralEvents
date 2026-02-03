-- ============================================================================
-- FIX: Add Unique Index on dedupe_key for ON CONFLICT to work
-- ============================================================================
-- The ON CONFLICT (dedupe_key) clause requires a unique constraint or index.
-- This script ensures the unique index exists.
-- ============================================================================

-- Check if unique index exists
SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'notifications'
  AND indexname LIKE '%dedupe%';

-- Drop existing index if it's not unique
DROP INDEX IF EXISTS idx_notifications_dedupe_key;

-- Create unique partial index (allows NULL values, but enforces uniqueness for non-NULL)
CREATE UNIQUE INDEX idx_notifications_dedupe_key 
ON notifications(dedupe_key) 
WHERE dedupe_key IS NOT NULL;

-- Verify it was created
SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'notifications'
  AND indexname = 'idx_notifications_dedupe_key';

-- Also check notification_events table
DROP INDEX IF EXISTS idx_notification_events_dedupe_key;

CREATE UNIQUE INDEX IF NOT EXISTS idx_notification_events_dedupe_key 
ON notification_events(dedupe_key) 
WHERE dedupe_key IS NOT NULL;

-- Verify both indexes exist
SELECT 
  'notifications' as table_name,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'notifications'
  AND indexname LIKE '%dedupe%'
UNION ALL
SELECT 
  'notification_events' as table_name,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'notification_events'
  AND indexname LIKE '%dedupe%';
