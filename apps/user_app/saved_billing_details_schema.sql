-- Saved Billing Details Table
CREATE TABLE IF NOT EXISTS saved_billing_details (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Billing details
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  message_to_vendor TEXT,
  
  -- Metadata
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_saved_billing_details_user 
  ON saved_billing_details(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_billing_details_user_default 
  ON saved_billing_details(user_id, is_default) WHERE is_default = true;

-- RLS Policies
ALTER TABLE saved_billing_details ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own saved billing details"
  ON saved_billing_details FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own saved billing details"
  ON saved_billing_details FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own saved billing details"
  ON saved_billing_details FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own saved billing details"
  ON saved_billing_details FOR DELETE
  USING (auth.uid() = user_id);
