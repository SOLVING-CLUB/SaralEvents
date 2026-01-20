-- FAQs Schema
-- For managing frequently asked questions in the support system

CREATE TABLE IF NOT EXISTS faqs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question TEXT NOT NULL,
  answer TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'General' CHECK (category IN (
    'General',
    'Booking',
    'Payment',
    'Cancellation',
    'Refund',
    'Technical',
    'Account',
    'Vendor',
    'Other'
  )),
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  view_count INTEGER DEFAULT 0,
  helpful_count INTEGER DEFAULT 0,
  not_helpful_count INTEGER DEFAULT 0,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_faqs_category ON faqs(category);
CREATE INDEX IF NOT EXISTS idx_faqs_is_active ON faqs(is_active);
CREATE INDEX IF NOT EXISTS idx_faqs_display_order ON faqs(display_order);

-- RLS Policies
ALTER TABLE faqs ENABLE ROW LEVEL SECURITY;

-- Everyone can view active FAQs
CREATE POLICY "Anyone can view active FAQs" ON faqs
  FOR SELECT USING (is_active = true);

-- Only admins can manage FAQs (this will be handled by service role in admin portal)
-- For authenticated users, we'll use service role bypass

-- Grant permissions
GRANT SELECT ON faqs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON faqs TO service_role;

-- Update trigger for updated_at
CREATE OR REPLACE FUNCTION update_faqs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_faqs_updated_at
  BEFORE UPDATE ON faqs
  FOR EACH ROW
  EXECUTE FUNCTION update_faqs_updated_at();
