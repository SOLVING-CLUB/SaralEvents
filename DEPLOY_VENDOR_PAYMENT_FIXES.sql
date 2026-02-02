-- ============================================================================
-- DEPLOY FIXES: Vendor Notifications & Payment Notifications
-- ============================================================================

-- ============================================================================
-- FIX 1: Update booking_status_change_notification to send to vendor
-- ============================================================================

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

    -- FIXED: Notify vendor about status change (for ALL status changes)
    IF v_vendor_user_id IS NOT NULL THEN
      PERFORM send_push_notification(
        v_vendor_user_id,
        CASE NEW.status
          WHEN 'confirmed' THEN 'Booking Confirmed by You'
          WHEN 'completed' THEN 'Order Completed'
          WHEN 'cancelled' THEN 'Booking Cancelled'
          ELSE 'Booking Status Update'
        END,
        CASE NEW.status
          WHEN 'confirmed' THEN 
            COALESCE('You confirmed booking for ' || v_service_name, 'Booking confirmed')
          WHEN 'completed' THEN 
            COALESCE('Order for ' || v_service_name || ' has been completed', 'Order completed')
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

-- ============================================================================
-- FIX 2: Verify payment trigger and check status values
-- ============================================================================

-- Check what status values exist in payment_milestones
SELECT 
  'Payment Status Values' as check_type,
  status,
  COUNT(*) as count
FROM payment_milestones
GROUP BY status
ORDER BY count DESC;

-- Check recent payment milestones
SELECT 
  'Recent Payment Milestones' as check_type,
  id,
  booking_id,
  milestone_type,
  status,
  amount,
  created_at,
  updated_at,
  CASE 
    WHEN status IN ('paid', 'held_in_escrow', 'released') THEN '✅ Should trigger notification'
    WHEN status IN ('success', 'completed', 'successful') THEN '⚠️ Status might need to be added to trigger'
    ELSE '❌ Status not in trigger condition'
  END as notification_status
FROM payment_milestones
WHERE created_at >= NOW() - INTERVAL '24 hours'
  OR updated_at >= NOW() - INTERVAL '24 hours'
ORDER BY COALESCE(updated_at, created_at) DESC
LIMIT 10;

-- Recreate payment trigger to ensure it's correct
DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;

CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
  EXECUTE FUNCTION notify_payment_success();

-- ============================================================================
-- VERIFY TRIGGERS
-- ============================================================================

SELECT 
  'Trigger Verification' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name IN (
    'booking_status_change_notification',
    'payment_success_notification'
  )
ORDER BY trigger_name;
