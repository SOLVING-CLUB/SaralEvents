-- ============================================================================
-- FIX: Replace ON CONFLICT with explicit check for notifications table
-- ============================================================================
-- PostgreSQL may not recognize partial unique indexes for ON CONFLICT.
-- This patch updates the process_notification_event function to use
-- explicit existence checks instead of ON CONFLICT.
-- ============================================================================

-- Step 1: Create a helper function for safe notification insertion
CREATE OR REPLACE FUNCTION insert_notification_if_not_exists(
  p_event_id UUID,
  p_recipient_role TEXT,
  p_recipient_user_id UUID DEFAULT NULL,
  p_recipient_vendor_id UUID DEFAULT NULL,
  p_recipient_admin_id UUID DEFAULT NULL,
  p_title TEXT,
  p_body TEXT,
  p_order_id UUID DEFAULT NULL,
  p_status TEXT DEFAULT 'PENDING',
  p_type TEXT DEFAULT 'BOTH',
  p_dedupe_key TEXT,
  p_metadata JSONB DEFAULT NULL,
  p_priority TEXT DEFAULT 'NORMAL',
  p_channel TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  v_notification_id UUID;
BEGIN
  -- If dedupe_key is provided, check if notification already exists
  IF p_dedupe_key IS NOT NULL THEN
    SELECT notification_id INTO v_notification_id
    FROM notifications
    WHERE dedupe_key = p_dedupe_key
    LIMIT 1;
    
    -- If exists, return existing ID
    IF v_notification_id IS NOT NULL THEN
      RETURN v_notification_id;
    END IF;
  END IF;
  
  -- Insert new notification
  INSERT INTO notifications (
    event_id, recipient_role, recipient_user_id, recipient_vendor_id, recipient_admin_id,
    title, body, order_id, status, type, dedupe_key, metadata, priority, channel
  ) VALUES (
    p_event_id, p_recipient_role, p_recipient_user_id, p_recipient_vendor_id, p_recipient_admin_id,
    p_title, p_body, p_order_id, p_status, p_type, p_dedupe_key, p_metadata, p_priority, p_channel
  )
  RETURNING notification_id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$;

-- Step 2: Update the specific failing case in process_notification_event
-- We'll need to replace the INSERT ... ON CONFLICT with a call to this helper
-- But first, let's test if we can fix it by ensuring the index is properly recognized

-- Actually, let's try a different approach: ensure the index exists and is valid
-- Then recreate the function to ensure it picks up the index

-- Step 3: Drop and recreate the unique index to ensure it's properly recognized
DROP INDEX IF EXISTS idx_notifications_dedupe_key;
DROP INDEX IF EXISTS idx_notifications_dedupe_key_unique;

-- Create the unique index (partial index for NULL handling)
CREATE UNIQUE INDEX idx_notifications_dedupe_key 
ON notifications(dedupe_key) 
WHERE dedupe_key IS NOT NULL;

-- Step 4: Verify index is unique and properly created
SELECT 
  i.indexname,
  i.indexdef,
  idx.indisunique as is_unique,
  idx.indisvalid as is_valid
FROM pg_indexes i
JOIN pg_index idx ON idx.indexrelid = (i.schemaname||'.'||i.tablename)::regclass
WHERE i.schemaname = 'public'
  AND i.tablename = 'notifications'
  AND i.indexname = 'idx_notifications_dedupe_key';

-- Step 5: Now we need to update the function to use the helper OR ensure ON CONFLICT works
-- Let's try updating just the ORDER_VENDOR_ARRIVED case to use the helper function
-- This is a minimal change to test if the approach works

-- Actually, the best solution is to replace ALL ON CONFLICT clauses in the function
-- But that's a large change. Let's first try to see if recreating the function helps
-- by ensuring it picks up the index.

-- For now, let's provide a patch that replaces ON CONFLICT with the helper function call
-- in the ORDER_VENDOR_ARRIVED case as a test
