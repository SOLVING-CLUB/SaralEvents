-- ============================================================================
-- DIAGNOSE: Payment Trigger After Update
-- ============================================================================

-- Step 1: Check pg_net queue for notification requests
SELECT 
  'pg_net Queue - Notification Requests' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅ Payment notification request'
    ELSE 'Other request'
  END as request_type
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- Step 2: Verify trigger exists and is correct
SELECT 
  'Trigger Verification' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  '✅ ACTIVE' as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';

-- Step 3: Check payment details and user/vendor IDs
SELECT 
  'Payment & User Details' as check_type,
  pm.id as payment_id,
  pm.status as payment_status,
  pm.updated_at,
  b.user_id,
  vp.user_id as vendor_user_id,
  CASE 
    WHEN b.user_id IS NULL THEN '❌ Missing user_id'
    WHEN vp.user_id IS NULL THEN '⚠️ Missing vendor_user_id'
    ELSE '✅ Both IDs present'
  END as id_status
FROM payment_milestones pm
JOIN bookings b ON b.id = pm.booking_id
LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
WHERE pm.id = 'cda32086-f5e7-424d-a382-9fe1fb99852f';

-- Step 4: Check FCM tokens for user and vendor
SELECT 
  'FCM Tokens Status' as check_type,
  ft.user_id,
  ft.app_type,
  ft.is_active,
  CASE 
    WHEN ft.is_active = true THEN '✅ Active token'
    ELSE '❌ Inactive token'
  END as token_status
FROM payment_milestones pm
JOIN bookings b ON b.id = pm.booking_id
LEFT JOIN vendor_profiles vp ON vp.id = b.vendor_id
LEFT JOIN fcm_tokens ft ON (
  (ft.user_id = b.user_id AND ft.app_type = 'user_app')
  OR (ft.user_id = vp.user_id AND ft.app_type = 'vendor_app')
)
WHERE pm.id = 'cda32086-f5e7-424d-a382-9fe1fb99852f'
ORDER BY ft.app_type, ft.is_active DESC;

-- Step 5: Test the trigger function directly with the payment ID
-- This will help us see if the function works when called directly
DO $$
DECLARE
  v_payment RECORD;
  v_booking RECORD;
  v_service_name TEXT;
  v_vendor_user_id UUID;
BEGIN
  -- Get the payment that was just updated
  SELECT * INTO v_payment
  FROM payment_milestones
  WHERE id = 'cda32086-f5e7-424d-a382-9fe1fb99852f';
  
  IF v_payment IS NOT NULL THEN
    RAISE NOTICE 'Testing notify_payment_success function directly...';
    RAISE NOTICE 'Payment ID: %, Status: %', v_payment.id, v_payment.status;
    
    -- Get booking details
    SELECT * INTO v_booking
    FROM bookings
    WHERE id = v_payment.booking_id;
    
    IF v_booking IS NOT NULL THEN
      RAISE NOTICE 'Booking ID: %, User ID: %', v_booking.id, v_booking.user_id;
      
      -- Get service name
      SELECT name INTO v_service_name
      FROM services
      WHERE id = v_booking.service_id;
      
      -- Get vendor's user_id
      SELECT user_id INTO v_vendor_user_id
      FROM vendor_profiles
      WHERE id = v_booking.vendor_id;
      
      RAISE NOTICE 'Service: %, Vendor User ID: %', v_service_name, v_vendor_user_id;
      
      -- Test notification for user
      IF v_booking.user_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_booking.user_id,
          'Payment Test (Direct)',
          'Testing payment notification directly',
          jsonb_build_object('type', 'test', 'payment_id', v_payment.id::TEXT),
          NULL,
          ARRAY['user_app']::TEXT[]
        );
        RAISE NOTICE '✅ User notification sent';
      END IF;
      
      -- Test notification for vendor
      IF v_vendor_user_id IS NOT NULL THEN
        PERFORM send_push_notification(
          v_vendor_user_id,
          'Payment Test (Direct)',
          'Testing payment notification directly',
          jsonb_build_object('type', 'test', 'payment_id', v_payment.id::TEXT),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
        RAISE NOTICE '✅ Vendor notification sent';
      END IF;
    ELSE
      RAISE NOTICE '❌ Booking not found';
    END IF;
  ELSE
    RAISE NOTICE '❌ Payment not found';
  END IF;
END $$;
