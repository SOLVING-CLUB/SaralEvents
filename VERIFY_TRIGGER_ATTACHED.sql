-- ============================================================================
-- VERIFY: Is Trigger Actually Attached to Table?
-- ============================================================================

-- Step 1: Check if trigger exists and is attached
SELECT 
  'Trigger Attachment Check' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  action_statement,
  CASE 
    WHEN trigger_name IS NOT NULL THEN '✅ Trigger is attached'
    ELSE '❌ Trigger NOT attached'
  END as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';

-- Step 2: Check ALL triggers on payment_milestones table
SELECT 
  'All Triggers on payment_milestones' as check_type,
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND event_object_table = 'payment_milestones';

-- Step 3: CRITICAL - Check pg_net queue for notification requests
-- This is the KEY check - if trigger fired, there should be a request
SELECT 
  '🔍 CRITICAL: pg_net Queue - Did Trigger Fire?' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅✅✅ TRIGGER FIRED!'
    ELSE '❌ No notification request'
  END as trigger_fired
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- Step 4: If no results, show ALL pg_net requests
SELECT 
  'All pg_net Requests (to see what IS in queue)' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 20;

-- Step 5: Test if we can manually call the trigger function
-- This simulates what the trigger should do
DO $$
DECLARE
  v_test_payment RECORD;
  v_old_status TEXT := 'pending';
  v_new_status TEXT := 'held_in_escrow';
BEGIN
  -- Get the payment we updated
  SELECT * INTO v_test_payment
  FROM payment_milestones
  WHERE id = 'cda32086-f5e7-424d-a382-9fe1fb99852f';
  
  IF v_test_payment IS NOT NULL THEN
    RAISE NOTICE 'Testing trigger function manually...';
    RAISE NOTICE 'Payment ID: %, Current Status: %', v_test_payment.id, v_test_payment.status;
    
    -- Manually call the function logic (simulating trigger)
    -- This will help us see if the function works when called directly
    PERFORM notify_payment_success();
    
    RAISE NOTICE 'Function call completed';
  ELSE
    RAISE NOTICE 'Payment not found';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error calling function: %', SQLERRM;
END $$;
