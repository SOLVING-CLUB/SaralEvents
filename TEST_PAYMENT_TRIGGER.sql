-- ============================================================================
-- TEST: Payment Notification Trigger
-- ============================================================================

-- Step 1: Check if there are any recent payment updates
SELECT 
  'Recent Payment Updates' as check_type,
  id,
  booking_id,
  milestone_type,
  status,
  amount,
  created_at,
  updated_at,
  CASE 
    WHEN updated_at >= NOW() - INTERVAL '1 hour' THEN '✅ Very recent - should have triggered'
    WHEN updated_at >= NOW() - INTERVAL '24 hours' THEN '⚠️ Recent - might have triggered'
    ELSE '❌ Old - won''t trigger now'
  END as trigger_status
FROM payment_milestones
WHERE status IN ('held_in_escrow', 'released')
  AND updated_at >= NOW() - INTERVAL '24 hours'
ORDER BY updated_at DESC
LIMIT 5;

-- Step 2: Get a pending payment to test with
SELECT 
  'Test Payment Available' as check_type,
  id,
  booking_id,
  milestone_type,
  status,
  amount,
  created_at
FROM payment_milestones
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 1;

-- Step 3: Check if trigger is actually firing by looking at pg_net queue
-- (This shows if the trigger is calling send_push_notification)
-- Note: pg_net version may not have created_at column, so we'll show all requests ordered by ID
SELECT 
  'Recent Notification Requests' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅ Payment notification request'
    ELSE 'Other request'
  END as request_type
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 10;

-- Step 4: Manual test - Update a pending payment to trigger notification
-- (Replace the payment_id with an actual ID from Step 2)
DO $$
DECLARE
  v_test_payment_id UUID;
  v_test_booking_id UUID;
  v_test_user_id UUID;
  v_old_status TEXT;
BEGIN
  -- Get a pending payment
  SELECT id, booking_id, status INTO v_test_payment_id, v_test_booking_id, v_old_status
  FROM payment_milestones
  WHERE status = 'pending'
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF v_test_payment_id IS NOT NULL THEN
    RAISE NOTICE 'Found test payment: id=%, booking_id=%, current_status=%', v_test_payment_id, v_test_booking_id, v_old_status;
    
    -- Get user_id from booking
    SELECT user_id INTO v_test_user_id
    FROM bookings
    WHERE id = v_test_booking_id;
    
    IF v_test_user_id IS NOT NULL THEN
      RAISE NOTICE 'Found user_id: %', v_test_user_id;
      RAISE NOTICE 'Updating payment status to held_in_escrow to trigger notification...';
      
      -- Update payment status - this should trigger the notification
      UPDATE payment_milestones
      SET status = 'held_in_escrow',
          updated_at = NOW()
      WHERE id = v_test_payment_id;
      
      RAISE NOTICE '✅ Payment updated. Check edge function logs for notification.';
      RAISE NOTICE 'Payment ID: %, User ID: %', v_test_payment_id, v_test_user_id;
    ELSE
      RAISE NOTICE '⚠️ No user_id found for booking_id: %', v_test_booking_id;
    END IF;
  ELSE
    RAISE NOTICE '⚠️ No pending payments found to test with';
  END IF;
END $$;

-- Step 5: Check the notification function directly
SELECT 
  'Direct Function Test' as check_type,
  send_push_notification(
    (SELECT user_id FROM bookings WHERE id = (SELECT booking_id FROM payment_milestones WHERE status = 'held_in_escrow' LIMIT 1)),
    'Payment Test',
    'Testing payment notification directly',
    jsonb_build_object('type', 'test', 'source', 'direct_function_test'),
    NULL,
    ARRAY['user_app']::TEXT[]
  ) as test_result;
