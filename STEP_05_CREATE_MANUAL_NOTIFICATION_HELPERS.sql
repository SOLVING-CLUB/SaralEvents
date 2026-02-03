-- ============================================================================
-- STEP 5: CREATE MANUAL NOTIFICATION HELPER FUNCTIONS
-- ============================================================================
-- These functions are called manually from your app code when users perform
-- specific actions that don't automatically trigger database events
-- ============================================================================

-- ============================================================================
-- HELPER 1: Vendor Marks Arrived at Location
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_vendor_arrived(
  p_order_id UUID DEFAULT NULL,
  p_booking_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN process_notification_event(
    p_event_code := 'ORDER_VENDOR_ARRIVED',
    p_order_id := p_order_id,
    p_booking_id := p_booking_id,
    p_actor_role := 'VENDOR',
    p_payload := jsonb_build_object('action', 'vendor_arrived')
  );
END;
$$;

-- ============================================================================
-- HELPER 2: User Confirms Vendor Arrival
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_user_confirm_arrival(
  p_order_id UUID DEFAULT NULL,
  p_booking_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN process_notification_event(
    p_event_code := 'ORDER_USER_CONFIRM_ARRIVAL',
    p_order_id := p_order_id,
    p_booking_id := p_booking_id,
    p_actor_role := 'USER',
    p_payload := jsonb_build_object('action', 'user_confirm_arrival')
  );
END;
$$;

-- ============================================================================
-- HELPER 3: Vendor Marks Setup Completed
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_vendor_setup_completed(
  p_order_id UUID DEFAULT NULL,
  p_booking_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN process_notification_event(
    p_event_code := 'ORDER_VENDOR_SETUP_COMPLETED',
    p_order_id := p_order_id,
    p_booking_id := p_booking_id,
    p_actor_role := 'VENDOR',
    p_payload := jsonb_build_object('action', 'vendor_setup_completed')
  );
END;
$$;

-- ============================================================================
-- HELPER 4: User Confirms Setup
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_user_confirm_setup(
  p_order_id UUID DEFAULT NULL,
  p_booking_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN process_notification_event(
    p_event_code := 'ORDER_USER_CONFIRM_SETUP',
    p_order_id := p_order_id,
    p_booking_id := p_booking_id,
    p_actor_role := 'USER',
    p_payload := jsonb_build_object('action', 'user_confirm_setup')
  );
END;
$$;

-- ============================================================================
-- HELPER 5: Campaign Broadcast (Admin sends campaign)
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_campaign_broadcast(
  p_campaign_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN process_notification_event(
    p_event_code := 'CAMPAIGN_BROADCAST',
    p_campaign_id := p_campaign_id,
    p_actor_role := 'ADMIN',
    p_payload := jsonb_build_object('action', 'campaign_broadcast')
  );
END;
$$;

-- ============================================================================
-- HELPER 6: Vendor Accepts/Rejects Order (Manual call if needed)
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_vendor_decision(
  p_order_id UUID DEFAULT NULL,
  p_booking_id UUID DEFAULT NULL,
  p_status TEXT DEFAULT 'accepted' -- 'accepted' or 'rejected'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN process_notification_event(
    p_event_code := 'ORDER_VENDOR_DECISION',
    p_order_id := p_order_id,
    p_booking_id := p_booking_id,
    p_actor_role := 'VENDOR',
    p_payload := jsonb_build_object('status', p_status)
  );
END;
$$;

-- ============================================================================
-- HELPER 7: User Cancels Order (Manual call if needed)
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_user_cancelled_order(
  p_order_id UUID DEFAULT NULL,
  p_booking_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN process_notification_event(
    p_event_code := 'ORDER_USER_CANCELLED',
    p_order_id := p_order_id,
    p_booking_id := p_booking_id,
    p_actor_role := 'USER',
    p_payload := jsonb_build_object('action', 'user_cancelled')
  );
END;
$$;

-- ============================================================================
-- HELPER 8: Vendor Cancels Order (Manual call if needed)
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_vendor_cancelled_order(
  p_order_id UUID DEFAULT NULL,
  p_booking_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN process_notification_event(
    p_event_code := 'ORDER_VENDOR_CANCELLED',
    p_order_id := p_order_id,
    p_booking_id := p_booking_id,
    p_actor_role := 'VENDOR',
    p_payload := jsonb_build_object('action', 'vendor_cancelled')
  );
END;
$$;

-- ============================================================================
-- HELPER 9: Vendor Completes Order (Manual call if needed)
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_vendor_completed_order(
  p_order_id UUID DEFAULT NULL,
  p_booking_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN process_notification_event(
    p_event_code := 'ORDER_VENDOR_COMPLETED',
    p_order_id := p_order_id,
    p_booking_id := p_booking_id,
    p_actor_role := 'VENDOR',
    p_payload := jsonb_build_object('action', 'vendor_completed')
  );
END;
$$;

-- ============================================================================
-- Verification Query
-- ============================================================================
SELECT 
  'Verification: Helper Functions Created' as check_type,
  routine_name,
  CASE 
    WHEN routine_name LIKE 'notify_%' THEN '✅ Created'
    ELSE '❌ Missing'
  END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'notify_vendor_arrived',
    'notify_user_confirm_arrival',
    'notify_vendor_setup_completed',
    'notify_user_confirm_setup',
    'notify_campaign_broadcast',
    'notify_vendor_decision',
    'notify_user_cancelled_order',
    'notify_vendor_cancelled_order',
    'notify_vendor_completed_order'
  )
ORDER BY routine_name;
