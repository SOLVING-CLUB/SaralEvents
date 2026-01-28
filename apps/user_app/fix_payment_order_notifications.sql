-- ============================================================================
-- FIX PAYMENT AND ORDER NOTIFICATIONS
-- This script fixes missing notifications for:
-- 1. Payment success (user app + vendor app)
-- 2. New order received (vendor app)
-- ============================================================================

-- Step 1: Ensure send_push_notification function exists
-- (If it doesn't exist, run automated_notification_triggers.sql first)

-- Step 2: Fix booking status change trigger to handle INSERT (new orders)
-- The current trigger only handles UPDATE, so new orders don't notify vendor

-- Create function to notify vendor about new bookings
CREATE OR REPLACE FUNCTION notify_new_booking()
RETURNS TRIGGER AS $$
DECLARE
  v_service_name TEXT;
  v_vendor_user_id UUID;
BEGIN
  -- Only notify vendor when a new booking is created (INSERT)
  -- Skip if booking is already in a terminal state
  IF NEW.status NOT IN ('cancelled', 'completed') THEN
    -- Get service name
    SELECT name INTO v_service_name
    FROM services
    WHERE id = NEW.service_id;

    -- Get vendor's user_id
    SELECT user_id INTO v_vendor_user_id
    FROM vendor_profiles
    WHERE id = NEW.vendor_id;

    -- Notify vendor about new order
    IF v_vendor_user_id IS NOT NULL THEN
      PERFORM send_push_notification(
        v_vendor_user_id,
        'New Order Received',
        COALESCE(
          'You have a new order for ' || v_service_name || '. Amount: ₹' || NEW.amount::TEXT,
          'You have a new order. Amount: ₹' || NEW.amount::TEXT
        ),
        jsonb_build_object(
          'type', 'new_order',
          'booking_id', NEW.id::TEXT,
          'service_id', NEW.service_id::TEXT,
          'amount', NEW.amount::TEXT,
          'status', NEW.status
        ),
        NULL,
        ARRAY['vendor_app']::TEXT[]
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS new_booking_notification ON bookings;

-- Create trigger for new bookings (INSERT)
CREATE TRIGGER new_booking_notification
  AFTER INSERT ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_booking();

-- Step 3: Fix payment success trigger - consolidate into single trigger
-- Drop all existing payment_success_notification triggers (may have duplicates)
DO $$
BEGIN
  -- Drop all instances of payment_success_notification trigger
  DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;
END $$;

-- Create single consolidated trigger that handles both INSERT and UPDATE
CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
  EXECUTE FUNCTION notify_payment_success();

-- Step 4: Verify booking status change trigger exists (for status updates)
DROP TRIGGER IF EXISTS booking_status_change_notification ON bookings;

CREATE TRIGGER booking_status_change_notification
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_booking_status_change();

-- Step 5: Verify all triggers are active
SELECT 
  'Trigger Verification' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  '✅ Active' as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name IN (
    'payment_success_notification',
    'booking_status_change_notification',
    'new_booking_notification'
  )
ORDER BY event_object_table, trigger_name;

-- Step 6: Test the setup
-- Check if functions exist
SELECT 
  'Function Verification' as check_type,
  routine_name,
  '✅ Exists' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'send_push_notification',
    'notify_payment_success',
    'notify_booking_status_change',
    'notify_new_booking'
  )
ORDER BY routine_name;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check recent bookings to see if they would trigger notifications
SELECT 
  'Recent Bookings Check' as check_type,
  b.id,
  b.status,
  b.created_at,
  CASE 
    WHEN b.created_at >= NOW() - INTERVAL '1 hour' THEN '✅ Should have triggered new_booking_notification'
    ELSE '⚠️ Older booking'
  END as notification_status
FROM bookings b
WHERE b.created_at >= NOW() - INTERVAL '24 hours'
ORDER BY b.created_at DESC
LIMIT 5;

-- Check recent payment milestones
SELECT 
  'Recent Payment Milestones Check' as check_type,
  pm.id,
  pm.milestone_type,
  pm.status,
  pm.amount,
  pm.updated_at,
  CASE 
    WHEN pm.status IN ('paid', 'held_in_escrow', 'released') 
      AND pm.updated_at >= NOW() - INTERVAL '1 hour' 
    THEN '✅ Should have triggered payment_success_notification'
    ELSE '⚠️ Check conditions'
  END as notification_status
FROM payment_milestones pm
WHERE pm.updated_at >= NOW() - INTERVAL '24 hours'
  OR pm.created_at >= NOW() - INTERVAL '24 hours'
ORDER BY pm.updated_at DESC, pm.created_at DESC
LIMIT 5;

-- Check pg_net request queue for recent activity
-- Note: Column structure varies by pg_net version
-- First check what columns are available
SELECT 
  'pg_net Table Structure' as check_type,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'net' 
  AND table_name = 'http_request_queue'
ORDER BY ordinal_position;

-- Count total requests (without time filter since column name may vary)
SELECT 
  'Total Notification Requests' as check_type,
  COUNT(*) as total_requests,
  'Check Supabase Dashboard > Logs for recent request details' as note
FROM net.http_request_queue;

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. New orders (INSERT) will now notify vendor via new_booking_notification trigger
-- 2. Payment success will notify both user and vendor via payment_success_notification trigger
-- 3. Status changes will notify user via booking_status_change_notification trigger
-- 4. Make sure send_push_notification function is working (check environment variables)
-- 5. Make sure edge function is deployed: supabase functions deploy send-push-notification
