-- Escrow Payment System Schema
-- Supports milestone-based payments: 20% advance, 50% on arrival, 30% on completion

-- Add milestone tracking columns to bookings table
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS milestone_status TEXT DEFAULT 'created' CHECK (milestone_status IN (
  'created',           -- Booking created, waiting for vendor acceptance
  'accepted',          -- Vendor accepted booking
  'vendor_traveling',  -- Vendor is traveling to location
  'vendor_arrived',    -- Vendor marked as arrived at location
  'arrival_confirmed', -- Customer confirmed vendor arrival
  'setup_completed',   -- Vendor marked setup as completed
  'setup_confirmed',   -- Customer confirmed setup completion
  'completed',         -- All milestones completed
  'cancelled'          -- Booking cancelled
));

ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS vendor_accepted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS vendor_traveling_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS vendor_arrived_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS arrival_confirmed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS setup_completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS setup_confirmed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- Payment milestones table
CREATE TABLE IF NOT EXISTS payment_milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  milestone_type TEXT NOT NULL CHECK (milestone_type IN ('advance', 'arrival', 'completion')),
  percentage INTEGER NOT NULL CHECK (percentage IN (20, 50, 30)),
  amount DECIMAL(10, 2) NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'held_in_escrow', 'released', 'refunded')),
  payment_id TEXT,
  gateway_order_id TEXT,
  gateway_payment_id TEXT,
  escrow_held_at TIMESTAMPTZ,
  escrow_released_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(booking_id, milestone_type)
);

CREATE INDEX IF NOT EXISTS idx_payment_milestones_booking_id ON payment_milestones(booking_id);
CREATE INDEX IF NOT EXISTS idx_payment_milestones_status ON payment_milestones(status);

-- Escrow transactions table (for admin tracking)
CREATE TABLE IF NOT EXISTS escrow_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  milestone_id UUID NOT NULL REFERENCES payment_milestones(id) ON DELETE CASCADE,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('hold', 'release', 'refund', 'commission_deduct')),
  amount DECIMAL(10, 2) NOT NULL,
  commission_amount DECIMAL(10, 2) DEFAULT 0,
  vendor_amount DECIMAL(10, 2) NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  admin_verified_by UUID, -- Admin user ID (can reference auth.users or admin_users if table exists)
  admin_verified_at TIMESTAMPTZ,
  vendor_wallet_credited BOOLEAN DEFAULT FALSE,
  vendor_wallet_transaction_id UUID,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_escrow_transactions_booking_id ON escrow_transactions(booking_id);
CREATE INDEX IF NOT EXISTS idx_escrow_transactions_status ON escrow_transactions(status);

-- Order notifications table (for tracking milestone notifications)
CREATE TABLE IF NOT EXISTS order_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL CHECK (notification_type IN (
    'booking_created',
    'vendor_accepted',
    'vendor_traveling',
    'vendor_arrived',
    'payment_due_arrival',
    'arrival_confirmed',
    'setup_completed',
    'payment_due_completion',
    'setup_confirmed',
    'payment_released',
    'booking_completed',
    'booking_cancelled'
  )),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  action_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_notifications_user_id ON order_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_order_notifications_booking_id ON order_notifications(booking_id);
CREATE INDEX IF NOT EXISTS idx_order_notifications_is_read ON order_notifications(is_read);

-- Function to create payment milestones when booking is created
CREATE OR REPLACE FUNCTION create_booking_payment_milestones()
RETURNS TRIGGER AS $$
DECLARE
  advance_amount DECIMAL(10, 2);
  arrival_amount DECIMAL(10, 2);
  completion_amount DECIMAL(10, 2);
BEGIN
  -- Calculate milestone amounts (20%, 50%, 30%)
  advance_amount := NEW.amount * 0.20;
  arrival_amount := NEW.amount * 0.50;
  completion_amount := NEW.amount * 0.30;
  
  -- Create advance payment milestone
  INSERT INTO payment_milestones (booking_id, milestone_type, percentage, amount, status)
  VALUES (NEW.id, 'advance', 20, advance_amount, 'pending');
  
  -- Create arrival payment milestone
  INSERT INTO payment_milestones (booking_id, milestone_type, percentage, amount, status)
  VALUES (NEW.id, 'arrival', 50, arrival_amount, 'pending');
  
  -- Create completion payment milestone
  INSERT INTO payment_milestones (booking_id, milestone_type, percentage, amount, status)
  VALUES (NEW.id, 'completion', 30, completion_amount, 'pending');
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create milestones on booking creation
DROP TRIGGER IF EXISTS trigger_create_payment_milestones ON bookings;
CREATE TRIGGER trigger_create_payment_milestones
  AFTER INSERT ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION create_booking_payment_milestones();

-- Function to update milestone status
CREATE OR REPLACE FUNCTION update_milestone_status(
  p_booking_id UUID,
  p_milestone_type TEXT,
  p_status TEXT,
  p_payment_id TEXT DEFAULT NULL,
  p_gateway_order_id TEXT DEFAULT NULL,
  p_gateway_payment_id TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE payment_milestones
  SET 
    status = p_status,
    payment_id = COALESCE(p_payment_id, payment_id),
    gateway_order_id = COALESCE(p_gateway_order_id, gateway_order_id),
    gateway_payment_id = COALESCE(p_gateway_payment_id, gateway_payment_id),
    escrow_held_at = CASE WHEN p_status = 'held_in_escrow' THEN NOW() ELSE escrow_held_at END,
    updated_at = NOW()
  WHERE booking_id = p_booking_id AND milestone_type = p_milestone_type;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to get booking with milestones
CREATE OR REPLACE FUNCTION get_booking_with_milestones(p_booking_id UUID)
RETURNS TABLE (
  booking JSONB,
  milestones JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    row_to_json(b.*)::jsonb as booking,
    COALESCE(
      json_agg(
        json_build_object(
          'id', pm.id,
          'milestone_type', pm.milestone_type,
          'percentage', pm.percentage,
          'amount', pm.amount,
          'status', pm.status,
          'payment_id', pm.payment_id,
          'created_at', pm.created_at,
          'updated_at', pm.updated_at
        )
      ) FILTER (WHERE pm.id IS NOT NULL),
      '[]'::json
    ) as milestones
  FROM bookings b
  LEFT JOIN payment_milestones pm ON pm.booking_id = b.id
  WHERE b.id = p_booking_id
  GROUP BY b.id;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON payment_milestones TO authenticated;
GRANT SELECT, INSERT, UPDATE ON escrow_transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON order_notifications TO authenticated;
GRANT EXECUTE ON FUNCTION create_booking_payment_milestones() TO authenticated;
GRANT EXECUTE ON FUNCTION update_milestone_status(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_booking_with_milestones(UUID) TO authenticated;


-- ------------------------------------------------------------------
-- Vendor Wallet Schema
-- ------------------------------------------------------------------

-- Wallet per vendor profile
CREATE TABLE IF NOT EXISTS vendor_wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL UNIQUE REFERENCES vendor_profiles(id) ON DELETE CASCADE,
  balance DECIMAL(12,2) NOT NULL DEFAULT 0,              -- available balance
  pending_withdrawal DECIMAL(12,2) NOT NULL DEFAULT 0,   -- locked for withdrawal requests
  total_earned DECIMAL(12,2) NOT NULL DEFAULT 0,         -- lifetime credits
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Wallet transaction ledger
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES vendor_wallets(id) ON DELETE CASCADE,
  vendor_id UUID NOT NULL REFERENCES vendor_profiles(id) ON DELETE CASCADE,
  txn_type TEXT NOT NULL CHECK (txn_type IN ('credit','debit')),
  source TEXT NOT NULL CHECK (source IN ('milestone_release','withdrawal','adjustment','refund','admin_adjustment')),
  amount DECIMAL(12,2) NOT NULL,
  balance_after DECIMAL(12,2) NOT NULL,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  milestone_id UUID REFERENCES payment_milestones(id) ON DELETE SET NULL,
  escrow_transaction_id UUID REFERENCES escrow_transactions(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Withdrawal requests (reviewed in company_web admin)
CREATE TABLE IF NOT EXISTS withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL REFERENCES vendor_profiles(id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES vendor_wallets(id) ON DELETE CASCADE,
  amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','processing','paid','failed')),
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  admin_id UUID, -- admin processing the payout (references auth.users or admin table)
  rejection_reason TEXT,
  bank_snapshot JSONB, -- captures account_number, ifsc, holder_name, bank_name at request time
  notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_vendor ON wallet_transactions(vendor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_vendor ON withdrawal_requests(vendor_id, status);

-- Grants
GRANT SELECT, INSERT, UPDATE ON vendor_wallets TO authenticated;
GRANT SELECT, INSERT, UPDATE ON wallet_transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON withdrawal_requests TO authenticated;


