-- ============================================================================
-- FIX: Replace all ON CONFLICT clauses with explicit existence checks
-- ============================================================================
-- PostgreSQL's ON CONFLICT may not recognize partial unique indexes.
-- This patch replaces all ON CONFLICT (dedupe_key) DO NOTHING with explicit checks.
-- ============================================================================

-- The pattern we're replacing:
--   INSERT INTO notifications (...) VALUES (...) 
--   ON CONFLICT (dedupe_key) DO NOTHING 
--   RETURNING notification_id INTO v_notification_id;
--
-- With:
--   SELECT notification_id INTO v_notification_id 
--   FROM notifications 
--   WHERE dedupe_key = v_dedupe_key;
--   
--   IF v_notification_id IS NULL THEN
--     INSERT INTO notifications (...) VALUES (...)
--     RETURNING notification_id INTO v_notification_id;
--   END IF;

-- This is a large change. Let's create a script that generates the updated function.
-- For now, let's fix just the ORDER_VENDOR_ARRIVED case as a test:

-- Read the current function definition and replace the INSERT statement
-- at line ~289-298 in STEP_03B_COMPLETE_REMAINING_NOTIFICATION_RULES.sql

-- The fix for ORDER_VENDOR_ARRIVED case:
-- Replace lines 288-298 with:

/*
      v_dedupe_key := 'ORDER_VENDOR_ARRIVED:USER:' || p_order_id::TEXT || ':' || v_order_record.user_id::TEXT;
      
      -- Check if notification already exists
      SELECT notification_id INTO v_notification_id
      FROM notifications
      WHERE dedupe_key = v_dedupe_key
      LIMIT 1;
      
      -- Only insert if it doesn't exist
      IF v_notification_id IS NULL THEN
        INSERT INTO notifications (
          event_id, recipient_role, recipient_user_id,
          title, body, order_id, status, type, dedupe_key, metadata
        ) VALUES (
          v_event_id, 'USER', v_order_record.user_id,
          'Vendor arrived', 'Vendor has arrived at your location',
          p_order_id, 'ARRIVED', 'BOTH', v_dedupe_key,
          jsonb_build_object('order_id', p_order_id, 'status', 'ARRIVED')
        )
        RETURNING notification_id INTO v_notification_id;
      END IF;
*/

-- However, we need to update the entire function. Let me create a helper that does this:
-- Actually, the best approach is to update STEP_03B_COMPLETE_REMAINING_NOTIFICATION_RULES.sql
-- directly. But that's a very large file. Let me create a patch file that shows the pattern
-- and then we can apply it systematically.

-- For now, let's try one more thing: ensure the index is created as a constraint
-- PostgreSQL might recognize constraints better than indexes for ON CONFLICT

-- Actually, you can't create a partial unique constraint directly in PostgreSQL.
-- You can only create partial unique indexes.

-- The real solution is to replace ON CONFLICT with explicit checks.
-- Let me create a Python-like script that shows the pattern, but we'll need to
-- manually update the SQL file or create a comprehensive replacement.

-- For immediate fix, let's update just the failing case:
