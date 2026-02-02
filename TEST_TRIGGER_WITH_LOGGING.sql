-- ============================================================================
-- TEST: Payment Trigger with Logging
-- ============================================================================

-- This will update a payment and show all the NOTICE messages
-- Run this and share ALL the NOTICE messages!

-- Step 1: Get a pending payment
SELECT 
  'Test Payment' as check_type,
  id,
  booking_id,
  status,
  amount
FROM payment_milestones
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 1;

-- Step 2: UPDATE PAYMENT - This will trigger the function with logging
DO $$
DECLARE
  v_payment_id UUID;
BEGIN
  -- Get a pending payment
  SELECT id INTO v_payment_id
  FROM payment_milestones
  WHERE status = 'pending'
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF v_payment_id IS NOT NULL THEN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'UPDATING PAYMENT TO TRIGGER NOTIFICATION';
    RAISE NOTICE 'Payment ID: %', v_payment_id;
    RAISE NOTICE '========================================';
    
    -- Update payment - this should trigger notify_payment_success
    UPDATE payment_milestones
    SET status = 'held_in_escrow',
        updated_at = NOW()
    WHERE id = v_payment_id;
    
    RAISE NOTICE '✅ Payment update SQL executed';
    RAISE NOTICE 'Check NOTICE messages above for trigger execution details';
  ELSE
    RAISE NOTICE '❌ No pending payments found';
  END IF;
END $$;

-- Step 3: Check pg_net queue after update
SELECT 
  'pg_net Queue After Update' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;
