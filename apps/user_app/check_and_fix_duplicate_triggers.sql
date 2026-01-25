-- ============================================================================
-- OPTIMIZE PAYMENT SUCCESS NOTIFICATION TRIGGER
-- This script consolidates separate INSERT and UPDATE triggers into one
-- ============================================================================
-- NOTE: This is optional optimization. Your current setup works fine!
-- The two separate triggers (INSERT and UPDATE) are functionally correct
-- but can be consolidated for cleaner code.

-- Step 1: Check current payment_success_notification triggers
SELECT 
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND trigger_name = 'payment_success_notification'
ORDER BY event_object_table, event_manipulation;

-- Step 2: Drop both separate triggers (INSERT and UPDATE)
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;

-- Step 3: Create single consolidated trigger (handles both INSERT and UPDATE)
CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
  EXECUTE FUNCTION notify_payment_success();

-- Step 4: Verify single consolidated trigger exists
SELECT 
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND trigger_name = 'payment_success_notification';

-- Expected result: Should show ONE trigger with event_manipulation = 'INSERT,UPDATE'
