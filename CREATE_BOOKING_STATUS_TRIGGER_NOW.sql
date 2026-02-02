-- ============================================================================
-- CREATE MISSING booking_status_change_notification TRIGGER
-- ============================================================================
-- This trigger is CRITICAL for order flow notifications
-- It sends notifications when booking status changes (pending → confirmed → completed → cancelled)

-- Step 1: Create the function (if it doesn't exist)
CREATE OR REPLACE FUNCTION notify_booking_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_service_name TEXT;
  v_vendor_user_id UUID;
BEGIN
  -- Only send notification if status actually changed
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    -- Get service name
    SELECT name INTO v_service_name
    FROM services
    WHERE id = NEW.service_id;

    -- Get vendor's user_id for vendor notifications
    SELECT user_id INTO v_vendor_user_id
    FROM vendor_profiles
    WHERE id = NEW.vendor_id;

    -- Notify user about status change
    PERFORM send_push_notification(
      NEW.user_id,
      CASE NEW.status
        WHEN 'confirmed' THEN 'Booking Confirmed'
        WHEN 'completed' THEN 'Order Completed'
        WHEN 'cancelled' THEN 'Booking Cancelled'
        ELSE 'Order Update'
      END,
      CASE NEW.status
        WHEN 'confirmed' THEN 
          COALESCE('Your booking for ' || v_service_name || ' has been confirmed!', 'Your booking has been confirmed!')
        WHEN 'completed' THEN 
          COALESCE('Your order for ' || v_service_name || ' has been completed. Thank you!', 'Your order has been completed.')
        WHEN 'cancelled' THEN 
          'Your booking has been cancelled. Refund will be processed as per policy.'
        ELSE 
          COALESCE('Your order for ' || v_service_name || ' status has been updated to ' || NEW.status, 
                   'Your order status has been updated to ' || NEW.status)
      END,
      jsonb_build_object(
        'type', 'booking_status_change',
        'booking_id', NEW.id::TEXT,
        'status', NEW.status,
        'old_status', OLD.status,
        'service_id', NEW.service_id::TEXT
      ),
      NULL,
      ARRAY['user_app']::TEXT[]
    );

    -- Notify vendor about status change (ONLY if vendor didn't perform the action)
    -- Skip notifications for 'confirmed' and 'completed' as vendor performed these actions
    IF v_vendor_user_id IS NOT NULL AND NEW.status NOT IN ('confirmed', 'completed') THEN
      PERFORM send_push_notification(
        v_vendor_user_id,
        CASE NEW.status
          WHEN 'cancelled' THEN 'Booking Cancelled'
          ELSE 'Booking Status Update'
        END,
        CASE NEW.status
          WHEN 'cancelled' THEN 
            'A booking has been cancelled'
          ELSE 
            COALESCE('Booking status updated to ' || NEW.status, 'Booking status updated')
        END,
        jsonb_build_object(
          'type', 'booking_status_change',
          'booking_id', NEW.id::TEXT,
          'status', NEW.status,
          'old_status', OLD.status,
          'service_id', NEW.service_id::TEXT
        ),
        NULL,
        ARRAY['vendor_app']::TEXT[]
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Drop existing trigger if it exists (to avoid duplicates)
DROP TRIGGER IF EXISTS booking_status_change_notification ON bookings;

-- Step 3: Create the trigger
CREATE TRIGGER booking_status_change_notification
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_booking_status_change();

-- Step 4: Verify trigger was created
SELECT 
  '✅ Trigger Created' as status,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'booking_status_change_notification';
