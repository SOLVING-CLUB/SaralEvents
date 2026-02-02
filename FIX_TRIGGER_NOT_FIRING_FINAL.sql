-- ============================================================================
-- FINAL FIX: Payment Trigger Not Firing
-- ============================================================================

-- The trigger is NOT firing. Let's verify everything and try a different approach.

-- Step 1: Verify trigger exists and check all details
SELECT 
  'Trigger Full Details' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  action_condition,
  action_statement,
  trigger_schema
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';

-- Step 2: Drop and recreate trigger completely
-- Sometimes triggers need to be recreated to work properly
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;

-- Recreate trigger
CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  EXECUTE FUNCTION notify_payment_success();

-- Step 3: Verify trigger was recreated
SELECT 
  'Trigger After Recreation' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  '✅ RECREATED' as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';

-- Step 4: Test with a fresh payment update
-- Get a pending payment
SELECT 
  'Test Payment for Fresh Update' as check_type,
  id,
  booking_id,
  status,
  amount
FROM payment_milestones
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 1;
