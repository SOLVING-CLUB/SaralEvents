-- ============================================================================
-- LIVE TEST: Payment Notification Trigger
-- ============================================================================

-- This will actually update a payment and trigger the notification

-- Step 1: Get a pending payment to test with
SELECT 
  'Test Payment Found' as check_type,
  id as payment_id,
  booking_id,
  milestone_type,
  status as current_status,
  amount
FROM payment_milestones
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 1;

-- Step 2: Get user_id and vendor_id for this payment
SELECT 
  'Payment Details' as check_type,
  pm.id as payment_id,
  pm.booking_id,
  pm.status as payment_status,
  b.user_id,
  vp.id as vendor_id,
  vp.user_id as vendor_user_id
FROM payment_milestones pm
JOIN bookings b ON b.id = pm.booking_id
LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
WHERE pm.status = 'pending'
ORDER BY pm.created_at DESC
LIMIT 1;

-- Step 3: Check current pg_net queue count (before update)
SELECT 
  'Before Update - pg_net Queue Count' as check_type,
  COUNT(*) as request_count
FROM net.http_request_queue;

-- Step 4: UPDATE A PAYMENT TO TRIGGER NOTIFICATION
-- This will actually change a pending payment to held_in_escrow
DO $$
DECLARE
  v_test_payment_id UUID;
  v_test_booking_id UUID;
  v_old_status TEXT;
  v_new_status TEXT := 'held_in_escrow';
BEGIN
  -- Get a pending payment
  SELECT id, booking_id, status INTO v_test_payment_id, v_test_booking_id, v_old_status
  FROM payment_milestones
  WHERE status = 'pending'
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF v_test_payment_id IS NOT NULL THEN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TESTING PAYMENT NOTIFICATION TRIGGER';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Payment ID: %', v_test_payment_id;
    RAISE NOTICE 'Booking ID: %', v_test_booking_id;
    RAISE NOTICE 'Old Status: %', v_old_status;
    RAISE NOTICE 'New Status: %', v_new_status;
    RAISE NOTICE 'Updating payment...';
    
    -- Update payment status - THIS SHOULD TRIGGER THE NOTIFICATION
    UPDATE payment_milestones
    SET status = v_new_status,
        updated_at = NOW()
    WHERE id = v_test_payment_id;
    
    RAISE NOTICE '✅ Payment updated successfully!';
    RAISE NOTICE 'The trigger should have fired and called send_push_notification';
    RAISE NOTICE 'Check edge function logs and pg_net queue for results';
    RAISE NOTICE '========================================';
  ELSE
    RAISE NOTICE '⚠️ No pending payments found to test with';
  END IF;
END $$;

-- Step 5: Check pg_net queue after update (should show new request)
SELECT 
  'After Update - Recent Notification Requests' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅ Payment notification request'
    ELSE 'Other request'
  END as request_type
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 5;

-- Step 6: Verify the payment was updated
SELECT 
  'Payment Update Verification' as check_type,
  id,
  booking_id,
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
