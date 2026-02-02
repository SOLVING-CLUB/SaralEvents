-- ============================================================================
-- FIX: Payment Trigger with Logging
-- ============================================================================

-- Add logging to the trigger function to see if it's being called
-- This will help us diagnose if the trigger is firing

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
      RAISE NOTICE '✅ User notification sent';

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
        RAISE NOTICE '✅ Vendor notification sent';
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

-- Verify trigger is still attached
SELECT 
  'Trigger Status After Function Update' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  '✅ ACTIVE' as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';
