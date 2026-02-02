-- ============================================================================
-- TEST: Payment Trigger After Fix
-- ============================================================================

-- After running FIX_PAYMENT_TRIGGER_ISSUE.sql, test the trigger again

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

-- Step 2: Update payment to trigger notification
-- Replace <payment_id> with the ID from Step 1
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
    RAISE NOTICE 'TESTING TRIGGER AFTER FIX';
    RAISE NOTICE 'Payment ID: %', v_payment_id;
    RAISE NOTICE 'Updating payment status...';
    
    -- Update payment
    UPDATE payment_milestones
    SET status = 'held_in_escrow',
        updated_at = NOW()
    WHERE id = v_payment_id;
    
    RAISE NOTICE '✅ Payment updated';
    RAISE NOTICE 'Check NOTICE messages from trigger function above';
    RAISE NOTICE 'Check pg_net queue below';
    RAISE NOTICE '========================================';
  ELSE
    RAISE NOTICE '❌ No pending payments found';
  END IF;
END $$;

-- Step 3: Check pg_net queue after update
SELECT 
  '🔍 pg_net Queue After Update' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅✅✅ TRIGGER FIRED!'
    ELSE 'Other request'
  END as result
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- Step 4: Show ALL recent pg_net requests
SELECT 
  'All Recent pg_net Requests' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 20;
