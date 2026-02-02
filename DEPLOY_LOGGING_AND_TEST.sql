-- ============================================================================
-- DEPLOY: Function with Logging and Test
-- ============================================================================

-- Step 1: Deploy the function with detailed logging
CREATE OR REPLACE FUNCTION notify_payment_success()
RETURNS TRIGGER AS $$
DECLARE
  v_booking RECORD;
  v_service_name TEXT;
  v_vendor_user_id UUID;
  v_should_notify BOOLEAN := FALSE;
BEGIN
  -- LOG: Trigger function called
  RAISE NOTICE '========================================';
  RAISE NOTICE 'notify_payment_success TRIGGER CALLED';
  RAISE NOTICE 'TG_OP: %, OLD.status: %, NEW.status: %', TG_OP, OLD.status, NEW.status;
  
  -- Only notify on successful payment (paid / held_in_escrow / released)
  IF NEW.status IN ('paid', 'held_in_escrow', 'released') THEN
    RAISE NOTICE '✅ Status matches trigger condition';
    
    -- For INSERT: always notify if status is in the success set
    -- For UPDATE: only notify if status changed from outside the success set into it
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND (OLD.status IS NULL OR OLD.status NOT IN ('paid', 'held_in_escrow', 'released'))) THEN
      RAISE NOTICE '✅ TG_OP condition matches - will send notification';
      v_should_notify := TRUE;
    ELSE
      RAISE NOTICE '❌ TG_OP condition does NOT match - skipping notification';
      RAISE NOTICE 'TG_OP: %, OLD.status: %, Condition check: %', TG_OP, OLD.status, 
        (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND (OLD.status IS NULL OR OLD.status NOT IN ('paid', 'held_in_escrow', 'released'))));
    END IF;
  ELSE
    RAISE NOTICE '❌ Status does NOT match trigger condition: %', NEW.status;
  END IF;
  
  IF v_should_notify THEN
    -- Get booking details
    SELECT * INTO v_booking
    FROM bookings
    WHERE id = NEW.booking_id;

    IF v_booking IS NOT NULL THEN
      RAISE NOTICE '✅ Booking found: User ID = %', v_booking.user_id;
      
      -- Get service name
      SELECT name INTO v_service_name
      FROM services
      WHERE id = v_booking.service_id;

      -- Get vendor's user_id
      SELECT user_id INTO v_vendor_user_id
      FROM vendor_profiles
      WHERE id = v_booking.vendor_id;

      RAISE NOTICE 'Service: %, Vendor User ID: %', v_service_name, v_vendor_user_id;

      -- Notify user about payment success
      RAISE NOTICE 'Sending notification to user...';
      PERFORM send_push_notification(
        v_booking.user_id,
        'Payment Successful',
        COALESCE(
          'Payment of ₹' || NEW.amount::TEXT || ' for ' || v_service_name || ' has been processed successfully',
          'Payment of ₹' || NEW.amount::TEXT || ' has been processed successfully'
        ),
        jsonb_build_object(
          'type', 'payment_success',
          'booking_id', NEW.booking_id::TEXT,
          'milestone_id', NEW.id::TEXT,
          'milestone_type', NEW.milestone_type,
          'amount', NEW.amount::TEXT,
          'status', NEW.status
        ),
        NULL,
        ARRAY['user_app']::TEXT[]
      );
      RAISE NOTICE '✅ User notification sent via send_push_notification';

      -- Notify vendor about payment received
      IF v_vendor_user_id IS NOT NULL THEN
        RAISE NOTICE 'Sending notification to vendor...';
        PERFORM send_push_notification(
          v_vendor_user_id,
          'Payment Received',
          COALESCE(
            'Payment of ₹' || NEW.amount::TEXT || ' received for ' || v_service_name,
            'Payment of ₹' || NEW.amount::TEXT || ' received'
          ),
          jsonb_build_object(
            'type', 'payment_received',
            'booking_id', NEW.booking_id::TEXT,
            'milestone_id', NEW.id::TEXT,
            'milestone_type', NEW.milestone_type,
            'amount', NEW.amount::TEXT,
            'status', NEW.status
          ),
          NULL,
          ARRAY['vendor_app']::TEXT[]
        );
        RAISE NOTICE '✅ Vendor notification sent via send_push_notification';
      ELSE
        RAISE NOTICE '⚠️ No vendor_user_id - skipping vendor notification';
      END IF;
    ELSE
      RAISE NOTICE '❌ Booking not found for booking_id: %', NEW.booking_id;
    END IF;
  END IF;
  
  RAISE NOTICE '========================================';

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '❌❌❌ ERROR in notify_payment_success: %', SQLERRM;
    RAISE NOTICE 'SQLSTATE: %', SQLSTATE;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Verify function was updated
SELECT 
  'Function Updated' as check_type,
  routine_name,
  routine_type,
  '✅ Function with logging deployed' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'notify_payment_success';

-- Step 3: Test with a simple trigger first
-- Create a test trigger to verify triggers work at all
CREATE OR REPLACE FUNCTION test_simple_trigger()
RETURNS TRIGGER AS $$
BEGIN
  RAISE NOTICE '🔔🔔🔔 SIMPLE TEST TRIGGER FIRED! TG_OP: %, NEW.id: %, NEW.status: %', TG_OP, NEW.id, NEW.status;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS test_simple_payment_trigger ON payment_milestones;

CREATE TRIGGER test_simple_payment_trigger
  AFTER UPDATE ON payment_milestones
  FOR EACH ROW
  EXECUTE FUNCTION test_simple_trigger();

-- Step 4: Test the simple trigger
-- Update a payment to see if simple trigger fires
UPDATE payment_milestones
SET updated_at = NOW()
WHERE id = 'fc3ab4fb-bede-470e-aff7-c93a61161e1c';

-- Step 5: Now test the actual payment trigger
-- Update payment status to trigger notification
UPDATE payment_milestones
SET status = 'released',
    updated_at = NOW()
WHERE id = 'fc3ab4fb-bede-470e-aff7-c93a61161e1c'
  AND status = 'held_in_escrow';

-- Step 6: Check pg_net queue after updates
SELECT 
  'pg_net Queue After Updates' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;
