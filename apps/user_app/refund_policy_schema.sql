-- Refund Policy Schema
-- Implements category-wise payment & refund policies

-- Refunds table
CREATE TABLE IF NOT EXISTS refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  cancelled_by TEXT NOT NULL CHECK (cancelled_by IN ('customer', 'vendor')),
  refund_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
  non_refundable_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
  refund_percentage DECIMAL(5, 2) NOT NULL DEFAULT 0,
  reason TEXT NOT NULL,
  breakdown JSONB DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'rejected')),
  admin_notes TEXT,
  processed_at TIMESTAMPTZ,
  processed_by UUID, -- Admin user ID
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Refund milestones (links refunds to payment milestones)
CREATE TABLE IF NOT EXISTS refund_milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  refund_id UUID NOT NULL REFERENCES refunds(id) ON DELETE CASCADE,
  milestone_id UUID NOT NULL REFERENCES payment_milestones(id) ON DELETE CASCADE,
  refund_amount DECIMAL(10, 2) NOT NULL,
  original_amount DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(refund_id, milestone_id)
);

-- Vendor cancellation penalties table
CREATE TABLE IF NOT EXISTS vendor_cancellation_penalties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL REFERENCES vendor_profiles(id) ON DELETE CASCADE,
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  penalty_type TEXT NOT NULL CHECK (penalty_type IN ('wallet_freeze', 'ranking_reduction', 'visibility_reduction', 'suspension', 'blacklist')),
  severity TEXT NOT NULL DEFAULT 'low' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'expired')),
  expires_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_refunds_booking_id ON refunds(booking_id);
CREATE INDEX IF NOT EXISTS idx_refunds_status ON refunds(status);
CREATE INDEX IF NOT EXISTS idx_refunds_cancelled_by ON refunds(cancelled_by);
CREATE INDEX IF NOT EXISTS idx_refund_milestones_refund_id ON refund_milestones(refund_id);
CREATE INDEX IF NOT EXISTS idx_refund_milestones_milestone_id ON refund_milestones(milestone_id);
CREATE INDEX IF NOT EXISTS idx_vendor_penalties_vendor_id ON vendor_cancellation_penalties(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_penalties_status ON vendor_cancellation_penalties(status);

-- Function to automatically create vendor penalty on vendor cancellation
CREATE OR REPLACE FUNCTION create_vendor_cancellation_penalty()
RETURNS TRIGGER AS $$
DECLARE
  vendor_id_val UUID;
  booking_date_val DATE;
BEGIN
  -- Only trigger on vendor cancellation
  IF NEW.status = 'cancelled' AND 
     EXISTS (
       SELECT 1 FROM refunds 
       WHERE booking_id = NEW.id 
       AND cancelled_by = 'vendor'
       AND status = 'pending'
     ) THEN
    
    -- Get vendor_id from booking
    SELECT b.vendor_id INTO vendor_id_val
    FROM bookings b
    WHERE b.id = NEW.id;
    
    -- Get booking date
    SELECT b.booking_date INTO booking_date_val
    FROM bookings b
    WHERE b.id = NEW.id;
    
    -- Check if vendor has previous cancellations
    DECLARE
      cancellation_count INTEGER;
    BEGIN
      SELECT COUNT(*) INTO cancellation_count
      FROM refunds r
      JOIN bookings b ON r.booking_id = b.id
      WHERE b.vendor_id = vendor_id_val
      AND r.cancelled_by = 'vendor'
      AND r.created_at > NOW() - INTERVAL '90 days';
      
      -- Apply penalties based on cancellation count
      IF cancellation_count = 1 THEN
        -- First cancellation: Wallet freeze + Ranking reduction
        INSERT INTO vendor_cancellation_penalties (vendor_id, booking_id, penalty_type, severity, status, expires_at)
        VALUES 
          (vendor_id_val, NEW.id, 'wallet_freeze', 'medium', 'active', NOW() + INTERVAL '7 days'),
          (vendor_id_val, NEW.id, 'ranking_reduction', 'medium', 'active', NOW() + INTERVAL '30 days');
      ELSIF cancellation_count = 2 THEN
        -- Second cancellation: All above + Visibility reduction
        INSERT INTO vendor_cancellation_penalties (vendor_id, booking_id, penalty_type, severity, status, expires_at)
        VALUES 
          (vendor_id_val, NEW.id, 'wallet_freeze', 'high', 'active', NOW() + INTERVAL '14 days'),
          (vendor_id_val, NEW.id, 'ranking_reduction', 'high', 'active', NOW() + INTERVAL '60 days'),
          (vendor_id_val, NEW.id, 'visibility_reduction', 'high', 'active', NOW() + INTERVAL '60 days');
      ELSIF cancellation_count >= 3 THEN
        -- Third+ cancellation: Suspension or blacklist
        INSERT INTO vendor_cancellation_penalties (vendor_id, booking_id, penalty_type, severity, status, expires_at)
        VALUES 
          (vendor_id_val, NEW.id, 'suspension', 'critical', 'active', NOW() + INTERVAL '90 days');
      END IF;
    END;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create vendor penalties on cancellation
DROP TRIGGER IF EXISTS trigger_vendor_cancellation_penalty ON bookings;
CREATE TRIGGER trigger_vendor_cancellation_penalty
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (NEW.status = 'cancelled' AND OLD.status != 'cancelled')
  EXECUTE FUNCTION create_vendor_cancellation_penalty();

-- Function to get refund summary for a booking
CREATE OR REPLACE FUNCTION get_refund_summary(p_booking_id UUID)
RETURNS TABLE (
  refund_id UUID,
  refund_amount DECIMAL(10, 2),
  non_refundable_amount DECIMAL(10, 2),
  refund_percentage DECIMAL(5, 2),
  reason TEXT,
  status TEXT,
  cancelled_by TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    r.id,
    r.refund_amount,
    r.non_refundable_amount,
    r.refund_percentage,
    r.reason,
    r.status,
    r.cancelled_by,
    r.created_at
  FROM refunds r
  WHERE r.booking_id = p_booking_id
  ORDER BY r.created_at DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to process vendor cancellation with automatic refund
CREATE OR REPLACE FUNCTION process_vendor_cancellation(
  p_booking_id UUID,
  p_reason TEXT DEFAULT 'Vendor cancellation'
)
RETURNS JSONB AS $$
DECLARE
  v_booking RECORD;
  v_total_paid DECIMAL(10, 2);
  v_refund_id UUID;
  v_milestone RECORD;
BEGIN
  -- Get booking details
  SELECT 
    b.id,
    b.vendor_id,
    b.amount,
    b.booking_date
  INTO v_booking
  FROM bookings b
  WHERE b.id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  -- Calculate total paid amount from milestones
  SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
  FROM payment_milestones
  WHERE booking_id = p_booking_id
  AND status IN ('held_in_escrow', 'released');

  -- Create refund record (100% refund for vendor cancellation)
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

  -- Update all paid milestones to refunded
  FOR v_milestone IN 
    SELECT id, amount
    FROM payment_milestones
    WHERE booking_id = p_booking_id
    AND status IN ('held_in_escrow', 'released')
  LOOP
    -- Update milestone status
    UPDATE payment_milestones
    SET status = 'refunded',
        updated_at = NOW()
    WHERE id = v_milestone.id;

    -- Create refund milestone record
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

  -- Update booking status
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

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON refunds TO authenticated;
GRANT SELECT, INSERT, UPDATE ON refund_milestones TO authenticated;
GRANT SELECT, INSERT, UPDATE ON vendor_cancellation_penalties TO authenticated;
GRANT EXECUTE ON FUNCTION get_refund_summary(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION process_vendor_cancellation(UUID, TEXT) TO authenticated;

-- RLS Policies
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE refund_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_cancellation_penalties ENABLE ROW LEVEL SECURITY;

-- Users can view refunds for their bookings
CREATE POLICY "Users can view their refunds" ON refunds
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = refunds.booking_id
      AND b.user_id = auth.uid()
    )
  );

-- Vendors can view refunds for their bookings
CREATE POLICY "Vendors can view their refunds" ON refunds
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = refunds.booking_id
      AND b.vendor_id IN (
        SELECT id FROM vendor_profiles WHERE user_id = auth.uid()
      )
    )
  );

-- Users can view refund milestones for their bookings
CREATE POLICY "Users can view their refund milestones" ON refund_milestones
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM refunds r
      JOIN bookings b ON r.booking_id = b.id
      WHERE r.id = refund_milestones.refund_id
      AND b.user_id = auth.uid()
    )
  );

-- Vendors can view their cancellation penalties
CREATE POLICY "Vendors can view their penalties" ON vendor_cancellation_penalties
  FOR SELECT USING (
    vendor_id IN (
      SELECT id FROM vendor_profiles WHERE user_id = auth.uid()
    )
  );

