-- Fix: prevent PostgresException 42704 ("unrecognized configuration parameter app.supabase_url")
-- by ensuring notification helper never calls current_setting('app.*') without missing_ok=true.
-- Also: make vendor-cancellation refund processing idempotent and include 'paid' milestones.

-- =============================================================================
-- Notification helper (pg_net variant recommended for Supabase)
-- =============================================================================
-- Note: Your DB may have either http-extension or pg_net variants installed.
-- This replaces the common helper name `send_push_notification` with a safe implementation.
-- If pg_net isn't enabled, this returns a "skipped" response instead of crashing.

CREATE OR REPLACE FUNCTION send_push_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT '{}'::JSONB,
  p_image_url TEXT DEFAULT NULL,
  p_app_types TEXT[] DEFAULT ARRAY['user_app', 'vendor_app']::TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_role_key TEXT;
  v_request_id BIGINT;
BEGIN
  v_supabase_url := current_setting('app.supabase_url', true);
  v_service_role_key := current_setting('app.supabase_service_role_key', true);

  IF v_supabase_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE WARNING 'Push notifications skipped: missing app.supabase_url or app.supabase_service_role_key';
    RETURN jsonb_build_object(
      'success', false,
      'skipped', true,
      'reason', 'missing_config'
    );
  END IF;

  -- Prefer pg_net if available. This is async and won't block the transaction.
  BEGIN
    SELECT id INTO v_request_id
    FROM net.http_post(
      url := v_supabase_url || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_service_role_key,
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'userId', p_user_id,
        'title', p_title,
        'body', p_body,
        'data', p_data,
        'imageUrl', COALESCE(p_image_url, ''),
        'appTypes', p_app_types
      )
    );

    RETURN jsonb_build_object(
      'success', true,
      'request_id', v_request_id,
      'message', 'Notification request queued'
    );
  EXCEPTION
    WHEN undefined_function OR invalid_schema_name OR undefined_table THEN
      -- net.http_post isn't available (pg_net not enabled). Don't crash the write.
      RAISE WARNING 'Push notifications skipped: pg_net not available';
      RETURN jsonb_build_object(
        'success', false,
        'skipped', true,
        'reason', 'pg_net_not_available'
      );
  END;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- =============================================================================
-- Vendor cancellation refund processing (idempotent)
-- =============================================================================

CREATE OR REPLACE FUNCTION process_vendor_cancellation(
  p_booking_id UUID,
  p_reason TEXT DEFAULT 'Vendor cancellation'
)
RETURNS JSONB AS $$
DECLARE
  v_booking RECORD;
  v_total_paid DECIMAL(10, 2);
  v_refund_id UUID;
  v_existing_refund_id UUID;
  v_existing_refund_amount DECIMAL(10, 2);
  v_milestone RECORD;
BEGIN
  SELECT b.id, b.vendor_id, b.amount, b.booking_date
  INTO v_booking
  FROM bookings b
  WHERE b.id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  SELECT r.id, r.refund_amount
  INTO v_existing_refund_id, v_existing_refund_amount
  FROM refunds r
  WHERE r.booking_id = p_booking_id
    AND r.cancelled_by = 'vendor'
    AND r.status IN ('pending', 'processing', 'completed')
  ORDER BY r.created_at DESC
  LIMIT 1;

  IF v_existing_refund_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_processed', true,
      'refund_id', v_existing_refund_id,
      'refund_amount', v_existing_refund_amount,
      'message', 'Vendor cancellation already processed.'
    );
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
  FROM payment_milestones
  WHERE booking_id = p_booking_id
    AND status IN ('paid', 'held_in_escrow', 'released');

  INSERT INTO refunds (
    booking_id,
    cancelled_by,
    refund_amount,
    non_refundable_amount,
    refund_percentage,
    reason,
    breakdown,
    status
  ) VALUES (
    p_booking_id,
    'vendor',
    v_total_paid,
    0.0,
    100.0,
    'Vendor cancellation - Full refund of all payments',
    jsonb_build_object(
      'category', 'Vendor Cancellation',
      'is_vendor_cancellation', true,
      'total_paid', v_total_paid,
      'refund_percentage', 100.0,
      'reason', p_reason
    ),
    'pending'
  )
  RETURNING id INTO v_refund_id;

  FOR v_milestone IN
    SELECT id, amount
    FROM payment_milestones
    WHERE booking_id = p_booking_id
      AND status IN ('paid', 'held_in_escrow', 'released')
  LOOP
    UPDATE payment_milestones
    SET status = 'refunded',
        updated_at = NOW()
    WHERE id = v_milestone.id;

    INSERT INTO refund_milestones (
      refund_id,
      milestone_id,
      refund_amount,
      original_amount
    ) VALUES (
      v_refund_id,
      v_milestone.id,
      v_milestone.amount,
      v_milestone.amount
    );
  END LOOP;

  UPDATE bookings
  SET status = 'cancelled',
      updated_at = NOW()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'refund_id', v_refund_id,
    'refund_amount', v_total_paid,
    'message', 'Vendor cancellation processed. Full refund issued to customer.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

