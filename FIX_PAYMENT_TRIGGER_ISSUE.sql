-- ============================================================================
-- FIX: Payment Trigger Not Firing
-- ============================================================================

-- Issue: pg_net queue is empty, meaning trigger isn't firing
-- Let's check and fix the trigger condition

-- Step 1: Check current trigger definition
SELECT 
  'Current Trigger Definition' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  action_condition,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';

-- Step 2: Check if the WHEN clause might be preventing trigger from firing
-- The trigger has: WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
-- This should match 'held_in_escrow', but let's verify
SELECT 
  'Trigger WHEN Clause Test' as check_type,
  'held_in_escrow' as test_status,
  CASE 
    WHEN 'held_in_escrow' IN ('paid', 'held_in_escrow', 'released') THEN '✅ Should match trigger WHEN clause'
    ELSE '❌ Does NOT match trigger WHEN clause'
  END as when_clause_match;

-- Step 3: Recreate trigger WITHOUT WHEN clause to test
-- The WHEN clause might be causing issues, so let's move the condition into the function
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;

-- Create trigger WITHOUT WHEN clause - condition is handled in function
CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  EXECUTE FUNCTION notify_payment_success();

-- Step 4: Verify trigger was recreated
SELECT 
  'Trigger After Recreation' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  action_condition,
  '✅ ACTIVE' as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';

-- Step 5: Test by updating a payment again
-- Get a payment that's already held_in_escrow to test
SELECT 
  'Test Payment for Re-trigger' as check_type,
  id,
  booking_id,
  status,
  updated_at
FROM payment_milestones
WHERE status = 'held_in_escrow'
ORDER BY updated_at DESC
LIMIT 1;
