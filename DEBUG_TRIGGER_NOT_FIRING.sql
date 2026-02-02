-- ============================================================================
-- DEBUG: Why Trigger Is Not Firing
-- ============================================================================

-- Since pg_net queue is empty, the trigger is NOT firing
-- Let's check why

-- Step 1: Verify trigger is actually attached
SELECT 
  'Trigger Attachment Verification' as check_type,
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

-- Step 2: Check if function exists and is correct
SELECT 
  'Function Verification' as check_type,
  routine_name,
  routine_type,
  data_type as return_type,
  CASE 
    WHEN routine_name IS NOT NULL THEN '✅ Function exists'
    ELSE '❌ Function does NOT exist'
  END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'notify_payment_success';

-- Step 3: Test the function directly (simulate trigger call)
-- This will help us see if the function works when called directly
DO $$
DECLARE
  v_payment RECORD;
  v_old_status TEXT := 'pending';
  v_new_status TEXT := 'held_in_escrow';
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'TESTING notify_payment_success FUNCTION DIRECTLY';
  RAISE NOTICE '========================================';
  
  -- Get a payment that was updated
  SELECT * INTO v_payment
  FROM payment_milestones
  WHERE id = 'fc3ab4fb-bede-470e-aff7-c93a61161e1c';
  
  IF v_payment IS NOT NULL THEN
    RAISE NOTICE 'Payment ID: %', v_payment.id;
    RAISE NOTICE 'Current Status: %', v_payment.status;
    RAISE NOTICE 'Booking ID: %', v_payment.booking_id;
    
    -- Simulate what the trigger should do
    -- Check if status matches
    IF v_payment.status IN ('paid', 'held_in_escrow', 'released') THEN
      RAISE NOTICE '✅ Status matches trigger condition';
      
      -- Check TG_OP condition (simulating UPDATE)
      IF v_old_status IS NULL OR v_old_status NOT IN ('paid', 'held_in_escrow', 'released') THEN
        RAISE NOTICE '✅ TG_OP condition would match (UPDATE with OLD.status = pending)';
        RAISE NOTICE 'Function should execute and send notification';
      ELSE
        RAISE NOTICE '❌ TG_OP condition would NOT match';
      END IF;
    ELSE
      RAISE NOTICE '❌ Status does NOT match trigger condition';
    END IF;
  ELSE
    RAISE NOTICE '❌ Payment not found';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;

-- Step 4: Check if there are any PostgreSQL errors
-- Check Supabase Dashboard → Database → Logs for errors

-- Step 5: Try to manually call the trigger function with a test
-- This will show us if the function works at all
DO $$
DECLARE
  v_test_result TEXT;
BEGIN
  RAISE NOTICE 'Attempting to call notify_payment_success function...';
  
  -- We can't directly call a trigger function, but we can test the logic
  RAISE NOTICE 'Note: Trigger functions can only be called by triggers';
  RAISE NOTICE 'If trigger is not firing, check:';
  RAISE NOTICE '1. Is trigger attached? (Check Step 1)';
  RAISE NOTICE '2. Are there errors in PostgreSQL logs?';
  RAISE NOTICE '3. Is the trigger condition preventing execution?';
END $$;

-- Step 6: Check if send_push_notification function works
-- Test it directly to ensure it's not the issue
SELECT 
  'Testing send_push_notification' as check_type,
  send_push_notification(
    'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
    'Test Notification',
    'Testing if send_push_notification works',
    jsonb_build_object('type', 'test'),
    NULL,
    ARRAY['user_app']::TEXT[]
  ) as test_result;
