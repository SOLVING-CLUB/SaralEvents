-- Cart Items Table for persistent, cross-device cart
CREATE TABLE IF NOT EXISTS cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  vendor_id UUID NOT NULL REFERENCES vendor_profiles(id) ON DELETE CASCADE,
  
  -- Cart fields
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  subtitle TEXT,
  
  -- Booking-specific fields (can be null until checkout)
  booking_date DATE,
  booking_time TIME,
  event_date DATE,
  notes TEXT,
  
  -- Billing details (can be null until checkout)
  billing_name TEXT,
  billing_email TEXT,
  billing_phone TEXT,
  message_to_vendor TEXT,
  
  -- Status: 'active' (in cart), 'saved_for_later', 'checkout_pending', 'completed'
  status TEXT NOT NULL DEFAULT 'active' 
    CHECK (status IN ('active', 'saved_for_later', 'checkout_pending', 'completed')),
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days')
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_cart_items_user_status 
  ON cart_items(user_id, status);
CREATE INDEX IF NOT EXISTS idx_cart_items_user_active 
  ON cart_items(user_id) WHERE status IN ('active', 'saved_for_later');

-- RLS Policies
ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own cart items"
  ON cart_items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own cart items"
  ON cart_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own cart items"
  ON cart_items FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own cart items"
  ON cart_items FOR DELETE
  USING (auth.uid() = user_id);
