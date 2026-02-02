-- ============================================================================
-- FIX: Payment Notifications - Verify and Fix
-- ============================================================================

-- Your payment status values: 'released', 'pending', 'held_in_escrow', 'refunded'
-- Trigger looks for: 'paid', 'held_in_escrow', 'released'
-- Issue: 'paid' doesn't exist, but 'held_in_escrow' and 'released' should work

-- ============================================================================
-- STEP 1: Check recent payment milestones that should trigger
-- ============================================================================

SELECT 
  'Recent Payments - Should Trigger' as check_type,
  id,
  booking_id,
  milestone_type,
  status,
  amount,
  created_at,
  updated_at,
  CASE 
    WHEN status = 'held_in_escrow' THEN '✅ Should trigger (held_in_escrow)'
    WHEN status = 'released' THEN '✅ Should trigger (released)'
    WHEN status = 'pending' THEN '⚠️ Pending - will trigger when updated to held_in_escrow/released'
    WHEN status = 'refunded' THEN '❌ Refunded - will not trigger'
    ELSE '❓ Unknown status'
  END as notification_status
FROM payment_milestones
WHERE status IN ('held_in_escrow', 'released')
  AND (created_at >= NOW() - INTERVAL '24 hours' OR updated_at >= NOW() - INTERVAL '24 hours')
ORDER BY COALESCE(updated_at, created_at) DESC
LIMIT 10;

-- ============================================================================
-- STEP 2: Verify payment trigger exists and is correct
-- ============================================================================

SELECT 
  'Payment Trigger Status' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  '✅ ACTIVE' as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';

-- ============================================================================
-- STEP 3: Recreate payment trigger to ensure it's correct
-- ============================================================================

DROP TRIGGER IF EXISTS payment_success_notification ON payment_milestones;

CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))  -- 'paid' included for compatibility, but 'held_in_escrow' and 'released' are what you use
  EXECUTE FUNCTION notify_payment_success();

-- ============================================================================
-- STEP 4: Test payment notification manually
-- ============================================================================

-- Get a recent payment milestone to test with
DO $$
DECLARE
  v_test_payment_id UUID;
  v_test_booking_id UUID;
  v_test_user_id UUID;
BEGIN
  -- Get a recent payment with held_in_escrow or released status
  SELECT id, booking_id INTO v_test_payment_id, v_test_booking_id
  FROM payment_milestones
  WHERE status IN ('held_in_escrow', 'released')
  ORDER BY COALESCE(updated_at, created_at) DESC
  LIMIT 1;
  
  IF v_test_payment_id IS NOT NULL THEN
    -- Get user_id from booking
    SELECT user_id INTO v_test_user_id
    FROM bookings
    WHERE id = v_test_booking_id;
    
    IF v_test_user_id IS NOT NULL THEN
      -- Test notification
      PERFORM send_push_notification(
        v_test_user_id,
        'Payment Test',
        'Testing payment notification trigger',
        jsonb_build_object('type', 'test', 'payment_id', v_test_payment_id::TEXT),
        NULL,
        ARRAY['user_app']::TEXT[]
      );
      
      RAISE NOTICE '✅ Test notification sent for payment_id: %, user_id: %', v_test_payment_id, v_test_user_id;
    ELSE
      RAISE NOTICE '⚠️ No user_id found for booking_id: %', v_test_booking_id;
    END IF;
  ELSE
    RAISE NOTICE '⚠️ No recent payments with held_in_escrow or released status found';
  END IF;
END $$;

-- ============================================================================
-- STEP 5: Check if payments are being created/updated correctly
-- ============================================================================

SELECT 
  'Payment Creation Pattern' as check_type,
  CASE 
    WHEN created_at = updated_at THEN 'Created with final status'
    ELSE 'Updated after creation'
  END as creation_pattern,
  status,
  COUNT(*) as count
FROM payment_milestones
WHERE status IN ('held_in_escrow', 'released')
GROUP BY 
  CASE 
    WHEN created_at = updated_at THEN 'Created with final status'
    ELSE 'Updated after creation'
  END,
  status
ORDER BY count DESC;
