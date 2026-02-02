-- ============================================================================
-- FINAL DIAGNOSIS: Why Payment Trigger Isn't Firing
-- ============================================================================

-- Step 1: CRITICAL - Check pg_net queue (MOST IMPORTANT)
SELECT 
  '🔍 CRITICAL: pg_net Queue Check' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅✅✅ TRIGGER FIRED!'
    ELSE '❌ No notification request'
  END as trigger_fired_status
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- Step 2: If no results above, show ALL requests
SELECT 
  'All pg_net Requests (Last 30)' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 30;

-- Step 3: Check the payment that was updated
-- Verify OLD.status vs NEW.status logic
SELECT 
  'Payment Status Logic Check' as check_type,
  pm.id,
  pm.status as current_status,
  pm.created_at,
  pm.updated_at,
  CASE 
    WHEN pm.status IN ('paid', 'held_in_escrow', 'released') THEN '✅ Status matches trigger WHEN clause'
    ELSE '❌ Status does NOT match'
  END as trigger_when_match,
  CASE 
    WHEN pm.created_at = pm.updated_at THEN 'Created with final status (INSERT should trigger)'
    ELSE 'Updated after creation (UPDATE should trigger if OLD.status was pending)'
  END as creation_pattern
FROM payment_milestones pm
WHERE pm.id = 'cda32086-f5e7-424d-a382-9fe1fb99852f';

-- Step 4: Test the trigger function directly with a simulated UPDATE
-- This will help us see if the function works when called
DO $$
DECLARE
  v_payment RECORD;
  v_booking RECORD;
  v_service_name TEXT;
  v_vendor_user_id UUID;
BEGIN
  -- Get the payment
  SELECT * INTO v_payment
  FROM payment_milestones
  WHERE id = 'cda32086-f5e7-424d-a382-9fe1fb99852f';
  
  IF v_payment IS NOT NULL THEN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TESTING notify_payment_success FUNCTION';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Payment ID: %', v_payment.id;
    RAISE NOTICE 'Status: %', v_payment.status;
    RAISE NOTICE 'Booking ID: %', v_payment.booking_id;
    
    -- Check if status matches trigger condition
    IF v_payment.status IN ('paid', 'held_in_escrow', 'released') THEN
      RAISE NOTICE '✅ Status matches trigger condition';
      
      -- Get booking
      SELECT * INTO v_booking
      FROM bookings
      WHERE id = v_payment.booking_id;
      
      IF v_booking IS NOT NULL THEN
        RAISE NOTICE '✅ Booking found: User ID = %', v_booking.user_id;
        
        -- Get service name
        SELECT name INTO v_service_name
        FROM services
        WHERE id = v_booking.service_id;
        
        -- Get vendor user_id
        SELECT user_id INTO v_vendor_user_id
        FROM vendor_profiles
        WHERE id = v_booking.vendor_id;
        
        RAISE NOTICE 'Service: %, Vendor User ID: %', v_service_name, v_vendor_user_id;
        
        -- Test notification for user
        IF v_booking.user_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_booking.user_id,
            'Payment Test (Manual)',
            'Testing payment notification manually',
            jsonb_build_object('type', 'test', 'payment_id', v_payment.id::TEXT),
            NULL,
            ARRAY['user_app']::TEXT[]
          );
          RAISE NOTICE '✅ User notification sent via send_push_notification';
        END IF;
        
        -- Test notification for vendor
        IF v_vendor_user_id IS NOT NULL THEN
          PERFORM send_push_notification(
            v_vendor_user_id,
            'Payment Test (Manual)',
            'Testing payment notification manually',
            jsonb_build_object('type', 'test', 'payment_id', v_payment.id::TEXT),
            NULL,
            ARRAY['vendor_app']::TEXT[]
          );
          RAISE NOTICE '✅ Vendor notification sent via send_push_notification';
        END IF;
      ELSE
        RAISE NOTICE '❌ Booking not found';
      END IF;
    ELSE
      RAISE NOTICE '❌ Status does NOT match trigger condition';
    END IF;
    RAISE NOTICE '========================================';
  ELSE
    RAISE NOTICE '❌ Payment not found';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '❌ ERROR: %', SQLERRM;
END $$;

-- Step 5: Check if there are any PostgreSQL errors in logs
-- (This is informational - you may need to check Supabase dashboard for actual logs)
SELECT 
  'PostgreSQL Log Check' as check_type,
  'Check Supabase Dashboard → Database → Logs for any trigger errors' as instruction;
