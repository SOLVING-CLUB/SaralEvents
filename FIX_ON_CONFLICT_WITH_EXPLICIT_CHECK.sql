-- ============================================================================
-- FIX: Replace ON CONFLICT with explicit existence check
-- ============================================================================
-- PostgreSQL's ON CONFLICT may not recognize partial unique indexes in all cases.
-- This patch replaces ON CONFLICT (dedupe_key) DO NOTHING with an explicit check.
-- ============================================================================

-- First, let's create a helper function to safely insert notifications
CREATE OR REPLACE FUNCTION insert_notification_safe(
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
  -- Check if notification with this dedupe_key already exists
  IF p_dedupe_key IS NOT NULL THEN
    SELECT notification_id INTO v_notification_id
    FROM notifications
    WHERE dedupe_key = p_dedupe_key
    LIMIT 1;
    
    IF v_notification_id IS NOT NULL THEN
      -- Notification already exists, return existing ID
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

-- Verify function was created
SELECT 
  'Helper function created' as status,
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'insert_notification_safe';

-- ============================================================================
-- NOTE: This helper function can be used to replace all ON CONFLICT clauses
-- in the process_notification_event function. However, that would require
-- updating the entire function. For now, let's try a different approach:
-- Ensure the unique index is properly recognized by recreating it.
-- ============================================================================
