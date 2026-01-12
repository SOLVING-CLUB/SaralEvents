-- Booking Drafts Schema
-- Stores booking details before payment is completed

CREATE TABLE IF NOT EXISTS booking_drafts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  vendor_id UUID NOT NULL REFERENCES vendor_profiles(id) ON DELETE CASCADE,
  booking_date DATE,
  booking_time TIME,
  amount DECIMAL(10,2) NOT NULL,
  notes TEXT,
  -- Billing details (stored as JSON)
  billing_name TEXT,
  billing_email TEXT,
  billing_phone TEXT,
  event_date DATE,
  message_to_vendor TEXT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'payment_pending', 'completed', 'expired')),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add billing detail columns if they don't exist (for existing tables)
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'booking_drafts' AND column_name = 'billing_name') THEN
    ALTER TABLE booking_drafts ADD COLUMN billing_name TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'booking_drafts' AND column_name = 'billing_email') THEN
    ALTER TABLE booking_drafts ADD COLUMN billing_email TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'booking_drafts' AND column_name = 'billing_phone') THEN
    ALTER TABLE booking_drafts ADD COLUMN billing_phone TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'booking_drafts' AND column_name = 'event_date') THEN
    ALTER TABLE booking_drafts ADD COLUMN event_date DATE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'booking_drafts' AND column_name = 'message_to_vendor') THEN
    ALTER TABLE booking_drafts ADD COLUMN message_to_vendor TEXT;
  END IF;
  -- Make booking_date nullable if it's not already
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'booking_drafts' AND column_name = 'booking_date' AND is_nullable = 'NO') THEN
    ALTER TABLE booking_drafts ALTER COLUMN booking_date DROP NOT NULL;
  END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_booking_drafts_user_id ON booking_drafts(user_id);
CREATE INDEX IF NOT EXISTS idx_booking_drafts_status ON booking_drafts(status);
CREATE INDEX IF NOT EXISTS idx_booking_drafts_expires_at ON booking_drafts(expires_at);

-- RLS Policies
ALTER TABLE booking_drafts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their drafts" ON booking_drafts;
DROP POLICY IF EXISTS "Users can create their drafts" ON booking_drafts;
DROP POLICY IF EXISTS "Users can update their drafts" ON booking_drafts;
DROP POLICY IF EXISTS "Users can delete their drafts" ON booking_drafts;

-- Users can view and manage their own drafts
CREATE POLICY "Users can view their drafts" ON booking_drafts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their drafts" ON booking_drafts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their drafts" ON booking_drafts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their drafts" ON booking_drafts
  FOR DELETE USING (auth.uid() = user_id);

-- Function to clean up expired drafts
CREATE OR REPLACE FUNCTION cleanup_expired_drafts()
RETURNS void AS $$
BEGIN
  DELETE FROM booking_drafts
  WHERE expires_at < NOW()
  AND status = 'draft';
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON booking_drafts TO authenticated;

