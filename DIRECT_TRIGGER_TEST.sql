-- ============================================================================
-- DIRECT TEST: Force Trigger to Fire
-- ============================================================================

-- This will update a payment and immediately check if trigger fired

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

-- Step 2: Check pg_net queue BEFORE update
SELECT 
  'Before Update - pg_net Queue Count' as check_type,
  COUNT(*) as request_count,
  MAX(id) as latest_request_id
FROM net.http_request_queue;

-- Step 3: UPDATE PAYMENT AND CHECK IF TRIGGER FIRES
DO $$
DECLARE
  v_payment_id UUID;
  v_booking_id UUID;
  v_before_count BIGINT;
  v_after_count BIGINT;
  v_latest_id_before BIGINT;
  v_latest_id_after BIGINT;
BEGIN
  -- Get a pending payment
  SELECT id, booking_id INTO v_payment_id, v_booking_id
  FROM payment_milestones
  WHERE status = 'pending'
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF v_payment_id IS NOT NULL THEN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DIRECT TRIGGER TEST';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Payment ID: %', v_payment_id;
    RAISE NOTICE 'Booking ID: %', v_booking_id;
    
    -- Get pg_net queue count BEFORE
    SELECT COUNT(*), MAX(id) INTO v_before_count, v_latest_id_before
    FROM net.http_request_queue;
    
    RAISE NOTICE 'pg_net requests BEFORE: %, Latest ID: %', v_before_count, v_latest_id_before;
    
    -- UPDATE THE PAYMENT - This should trigger the notification
    RAISE NOTICE 'Updating payment status from pending to held_in_escrow...';
    
    UPDATE payment_milestones
    SET status = 'held_in_escrow',
        updated_at = NOW()
    WHERE id = v_payment_id;
    
    RAISE NOTICE '✅ Payment updated successfully';
    
    -- Wait a moment for async pg_net to process
    PERFORM pg_sleep(2);
    
    -- Get pg_net queue count AFTER
    SELECT COUNT(*), MAX(id) INTO v_after_count, v_latest_id_after
    FROM net.http_request_queue;
    
    RAISE NOTICE 'pg_net requests AFTER: %, Latest ID: %', v_after_count, v_latest_id_after;
    
    -- Check if new request was added
    IF v_after_count > v_before_count OR v_latest_id_after > v_latest_id_before THEN
      RAISE NOTICE '✅✅✅ TRIGGER FIRED! New request in pg_net queue';
    ELSE
      RAISE NOTICE '❌❌❌ TRIGGER DID NOT FIRE - No new request in pg_net queue';
    END IF;
    
    RAISE NOTICE '========================================';
  ELSE
    RAISE NOTICE '❌ No pending payments found';
  END IF;
END $$;

-- Step 4: Check pg_net queue AFTER update
SELECT 
  'After Update - Recent Notification Requests' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅✅✅ TRIGGER FIRED!'
    ELSE 'Other request'
  END as trigger_status
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- Step 5: Show ALL recent pg_net requests
SELECT 
  'All Recent pg_net Requests' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 20;

-- Step 6: Verify payment was updated
SELECT 
  'Payment Update Verification' as check_type,
  id,
  status,
  updated_at,
  CASE 
    WHEN status = 'held_in_escrow' THEN '✅ Updated successfully'
    ELSE '❌ Update failed'
  END as update_status
FROM payment_milestones
WHERE status = 'held_in_escrow'
ORDER BY updated_at DESC
LIMIT 1;
