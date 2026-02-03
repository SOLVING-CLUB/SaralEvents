-- ============================================================================
-- STEP 4: CREATE NOTIFICATION TRIGGERS
-- ============================================================================
-- This query creates database triggers that automatically call process_notification_event
-- when relevant events occur in the database
-- ============================================================================

-- ============================================================================
-- TRIGGER 1: Payment Success/Failure (payment_milestones)
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_payment_notification()
RETURNS TRIGGER AS $$
DECLARE
  v_order_id UUID;
BEGIN
  -- Get order_id from payment milestone
  v_order_id := NEW.order_id;
  
  -- Payment Success: When status changes to 'paid', 'held_in_escrow', or 'released'
  IF NEW.status IN ('paid', 'held_in_escrow', 'released') AND 
     (OLD.status IS NULL OR OLD.status NOT IN ('paid', 'held_in_escrow', 'released')) THEN
    
    -- If this is the first payment for an order, trigger ORDER_PAYMENT_SUCCESS
    IF v_order_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM payment_milestones 
      WHERE order_id = v_order_id 
      AND id != NEW.id 
      AND status IN ('paid', 'held_in_escrow', 'released')
    ) THEN
      PERFORM process_notification_event(
        p_event_code := 'ORDER_PAYMENT_SUCCESS',
        p_order_id := v_order_id,
        p_payment_id := NEW.id,
        p_actor_role := 'USER',
        p_payload := jsonb_build_object(
          'amount', NEW.amount,
          'status', NEW.status,
          'milestone_type', NEW.milestone_type
        )
      );
    ELSE
      -- Subsequent payments trigger PAYMENT_ANY_STAGE
      PERFORM process_notification_event(
        p_event_code := 'PAYMENT_ANY_STAGE',
        p_order_id := v_order_id,
        p_payment_id := NEW.id,
        p_actor_role := 'USER',
        p_payload := jsonb_build_object(
          'amount', NEW.amount,
          'status', NEW.status,
          'milestone_type', NEW.milestone_type
        )
      );
    END IF;
  END IF;
  
  -- Payment Failed: When status changes to 'failed' or payment fails
  IF NEW.status = 'failed' AND (OLD.status IS NULL OR OLD.status != 'failed') THEN
    PERFORM process_notification_event(
      p_event_code := 'ORDER_PAYMENT_FAILED',
      p_order_id := v_order_id,
      p_payment_id := NEW.id,
      p_actor_role := 'USER',
      p_payload := jsonb_build_object(
        'amount', NEW.amount,
        'status', 'failed'
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS payment_notification_trigger ON payment_milestones;
CREATE TRIGGER payment_notification_trigger
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  EXECUTE FUNCTION trigger_payment_notification();

-- ============================================================================
-- TRIGGER 2: Order Status Changes (orders table - if exists)
-- ============================================================================
-- Note: This assumes orders table exists. If not, triggers will be on bookings table.
-- Create trigger function for orders (will only be used if orders table exists)
CREATE OR REPLACE FUNCTION trigger_order_status_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Vendor accepts/rejects order
  IF NEW.status IN ('accepted', 'confirmed', 'rejected') AND 
     (OLD.status IS NULL OR OLD.status != NEW.status) THEN
    PERFORM process_notification_event(
      p_event_code := 'ORDER_VENDOR_DECISION',
      p_order_id := NEW.id,
      p_actor_role := 'VENDOR',
      p_payload := jsonb_build_object('status', NEW.status)
    );
  END IF;
  
  -- Vendor arrives (if status changes to 'arrived' or similar)
  IF NEW.status = 'arrived' AND (OLD.status IS NULL OR OLD.status != 'arrived') THEN
    PERFORM process_notification_event(
      p_event_code := 'ORDER_VENDOR_ARRIVED',
      p_order_id := NEW.id,
      p_actor_role := 'VENDOR',
      p_payload := jsonb_build_object('status', 'arrived')
    );
  END IF;
  
  -- Setup completed
  IF NEW.status = 'setup_completed' AND (OLD.status IS NULL OR OLD.status != 'setup_completed') THEN
    PERFORM process_notification_event(
      p_event_code := 'ORDER_VENDOR_SETUP_COMPLETED',
      p_order_id := NEW.id,
      p_actor_role := 'VENDOR',
      p_payload := jsonb_build_object('status', 'setup_completed')
    );
  END IF;
  
  -- Order completed
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    PERFORM process_notification_event(
      p_event_code := 'ORDER_VENDOR_COMPLETED',
      p_order_id := NEW.id,
      p_actor_role := 'VENDOR',
      p_payload := jsonb_build_object('status', 'completed')
    );
  END IF;
  
  -- User cancels order
  IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' AND 
     (NEW.cancelled_by = 'user' OR NEW.cancelled_by IS NULL) THEN
    PERFORM process_notification_event(
      p_event_code := 'ORDER_USER_CANCELLED',
      p_order_id := NEW.id,
      p_actor_role := 'USER',
      p_payload := jsonb_build_object('status', 'cancelled')
    );
  END IF;
  
  -- Vendor cancels order
  IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' AND NEW.cancelled_by = 'vendor' THEN
    PERFORM process_notification_event(
      p_event_code := 'ORDER_VENDOR_CANCELLED',
      p_order_id := NEW.id,
      p_actor_role := 'VENDOR',
      p_payload := jsonb_build_object('status', 'cancelled')
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger only if orders table exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'orders') THEN
    DROP TRIGGER IF EXISTS order_status_notification_trigger ON orders;
    EXECUTE 'CREATE TRIGGER order_status_notification_trigger
      AFTER UPDATE ON orders
      FOR EACH ROW
      WHEN (OLD.status IS DISTINCT FROM NEW.status)
      EXECUTE FUNCTION trigger_order_status_notification()';
  END IF;
END $$;

-- ============================================================================
-- TRIGGER 3: Booking Status Changes (bookings table)
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_booking_status_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Vendor accepts/rejects booking
  IF NEW.status IN ('confirmed', 'rejected') AND 
     (OLD.status IS NULL OR OLD.status != NEW.status) THEN
    PERFORM process_notification_event(
      p_event_code := 'ORDER_VENDOR_DECISION',
      p_booking_id := NEW.id,
      p_actor_role := 'VENDOR',
      p_payload := jsonb_build_object('status', NEW.status)
    );
  END IF;
  
  -- User cancels booking
  IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
    -- Check if cancelled by user (you may need to add a cancelled_by column)
    PERFORM process_notification_event(
      p_event_code := 'ORDER_USER_CANCELLED',
      p_booking_id := NEW.id,
      p_actor_role := 'USER',
      p_payload := jsonb_build_object('status', 'cancelled')
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS booking_status_notification_trigger ON bookings;
CREATE TRIGGER booking_status_notification_trigger
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION trigger_booking_status_notification();

-- ============================================================================
-- TRIGGER 4: Vendor Registration Approval (vendor_profiles)
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_vendor_approval_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- When vendor is approved
  IF NEW.approval_status = 'approved' AND 
     (OLD.approval_status IS NULL OR OLD.approval_status != 'approved') THEN
    PERFORM process_notification_event(
      p_event_code := 'VENDOR_REG_APPROVED',
      p_actor_role := 'ADMIN',
      p_actor_id := NEW.approved_by,
      p_payload := jsonb_build_object(
        'vendor_id', NEW.id,
        'approval_status', NEW.approval_status
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS vendor_approval_notification_trigger ON vendor_profiles;
CREATE TRIGGER vendor_approval_notification_trigger
  AFTER UPDATE ON vendor_profiles
  FOR EACH ROW
  WHEN (OLD.approval_status IS DISTINCT FROM NEW.approval_status)
  EXECUTE FUNCTION trigger_vendor_approval_notification();

-- ============================================================================
-- TRIGGER 5: Support Ticket Updates (support_tickets)
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_support_ticket_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- When admin adds notes or updates ticket
  IF NEW.admin_notes IS NOT NULL AND 
     (OLD.admin_notes IS NULL OR OLD.admin_notes != NEW.admin_notes) THEN
    PERFORM process_notification_event(
      p_event_code := 'SUPPORT_TICKET_UPDATED',
      p_ticket_id := NEW.id,
      p_actor_role := 'ADMIN',
      p_actor_id := NEW.resolved_by,
      p_payload := jsonb_build_object(
        'admin_message', NEW.admin_notes,
        'status', NEW.status
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS support_ticket_notification_trigger ON support_tickets;
CREATE TRIGGER support_ticket_notification_trigger
  AFTER UPDATE ON support_tickets
  FOR EACH ROW
  WHEN (OLD.admin_notes IS DISTINCT FROM NEW.admin_notes)
  EXECUTE FUNCTION trigger_support_ticket_notification();

-- ============================================================================
-- TRIGGER 6: Refund Initiated (refunds)
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_refund_initiated_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- When refund is created
  IF TG_OP = 'INSERT' THEN
    PERFORM process_notification_event(
      p_event_code := 'REFUND_INITIATED',
      p_refund_id := NEW.id,
      p_booking_id := NEW.booking_id,
      -- Normalise actor role to uppercase to satisfy notification_events_actor_role_check
      -- NEW.cancelled_by is typically 'user' or 'vendor' (lowercase)
      p_actor_role := UPPER(COALESCE(NEW.cancelled_by::TEXT, 'USER')),
      p_payload := jsonb_build_object(
        'customer_amount', COALESCE(NEW.customer_amount, 0),
        'vendor_amount', COALESCE(NEW.vendor_amount, 0),
        'refund_amount', NEW.refund_amount
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS refund_initiated_notification_trigger ON refunds;
CREATE TRIGGER refund_initiated_notification_trigger
  AFTER INSERT ON refunds
  FOR EACH ROW
  EXECUTE FUNCTION trigger_refund_initiated_notification();

-- ============================================================================
-- TRIGGER 7: Refund Approved (refunds)
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_refund_approved_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- When refund status changes to 'completed' (approved and processed)
  IF NEW.status = 'completed' AND 
     (OLD.status IS NULL OR OLD.status != 'completed') THEN
    PERFORM process_notification_event(
      p_event_code := 'REFUND_APPROVED',
      p_refund_id := NEW.id,
      p_booking_id := NEW.booking_id,
      p_actor_role := 'ADMIN',
      p_actor_id := NEW.processed_by,
      p_payload := jsonb_build_object(
        'customer_amount', COALESCE(NEW.customer_amount, 0),
        'vendor_amount', COALESCE(NEW.vendor_amount, 0),
        'status', NEW.status
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS refund_approved_notification_trigger ON refunds;
CREATE TRIGGER refund_approved_notification_trigger
  AFTER UPDATE ON refunds
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION trigger_refund_approved_notification();

-- ============================================================================
-- TRIGGER 8: Withdrawal Requested (withdrawal_requests)
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_withdrawal_requested_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- When withdrawal request is created
  IF TG_OP = 'INSERT' THEN
    PERFORM process_notification_event(
      p_event_code := 'VENDOR_WITHDRAWAL_REQUESTED',
      p_withdrawal_request_id := NEW.id,
      p_actor_role := 'VENDOR',
      p_payload := jsonb_build_object(
        'amount', NEW.amount,
        'status', NEW.status
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS withdrawal_requested_notification_trigger ON withdrawal_requests;
CREATE TRIGGER withdrawal_requested_notification_trigger
  AFTER INSERT ON withdrawal_requests
  FOR EACH ROW
  EXECUTE FUNCTION trigger_withdrawal_requested_notification();

-- ============================================================================
-- TRIGGER 9: Withdrawal Approved (withdrawal_requests)
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_withdrawal_approved_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- When withdrawal status changes to 'approved'
  IF NEW.status = 'approved' AND 
     (OLD.status IS NULL OR OLD.status != 'approved') THEN
    PERFORM process_notification_event(
      p_event_code := 'VENDOR_WITHDRAWAL_APPROVED',
      p_withdrawal_request_id := NEW.id,
      p_actor_role := 'ADMIN',
      p_actor_id := NEW.admin_id,
      p_payload := jsonb_build_object(
        'amount', NEW.amount,
        'status', NEW.status
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS withdrawal_approved_notification_trigger ON withdrawal_requests;
CREATE TRIGGER withdrawal_approved_notification_trigger
  AFTER UPDATE ON withdrawal_requests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION trigger_withdrawal_approved_notification();

-- ============================================================================
-- TRIGGER 10: Funds Released to Wallet (wallet_transactions)
-- ============================================================================
CREATE OR REPLACE FUNCTION trigger_funds_released_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- When funds are credited to vendor wallet
  IF NEW.txn_type = 'credit' AND NEW.source IN ('milestone_release', 'admin_adjustment') THEN
    PERFORM process_notification_event(
      p_event_code := 'VENDOR_FUNDS_RELEASED_TO_WALLET',
      p_actor_role := 'ADMIN',
      p_payload := jsonb_build_object(
        'wallet_transaction_id', NEW.id,
        'amount', NEW.amount,
        'source', NEW.source
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS funds_released_notification_trigger ON wallet_transactions;
CREATE TRIGGER funds_released_notification_trigger
  AFTER INSERT ON wallet_transactions
  FOR EACH ROW
  WHEN (NEW.txn_type = 'credit')
  EXECUTE FUNCTION trigger_funds_released_notification();

-- ============================================================================
-- Verification Query
-- ============================================================================
SELECT 
  'Verification: Triggers Created' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  CASE 
    WHEN trigger_name LIKE '%notification%' THEN '✅ Created'
    ELSE '❌ Missing'
  END as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE '%notification%'
ORDER BY event_object_table, trigger_name;
