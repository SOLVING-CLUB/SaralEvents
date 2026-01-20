-- Push Notification Campaigns Schema
-- Stores campaign notifications that can be sent instantly or scheduled

CREATE TABLE IF NOT EXISTS notification_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  cta_text TEXT,
  cta_url TEXT,
  cta_action TEXT, -- e.g., 'open_app', 'open_url', 'open_screen'
  target_audience TEXT NOT NULL CHECK (target_audience IN ('all_users', 'all_vendors', 'specific_users')),
  target_user_ids UUID[] DEFAULT '{}', -- For specific_users audience
  image_url TEXT,
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'scheduled', 'sending', 'sent', 'failed', 'cancelled')),
  sent_count INTEGER DEFAULT 0,
  failed_count INTEGER DEFAULT 0,
  total_recipients INTEGER DEFAULT 0,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON notification_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_scheduled_at ON notification_campaigns(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_campaigns_created_at ON notification_campaigns(created_at DESC);

-- RLS Policies
ALTER TABLE notification_campaigns ENABLE ROW LEVEL SECURITY;

-- Admins can view all campaigns
CREATE POLICY "Admins can view campaigns" ON notification_campaigns
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- Admins can create campaigns
CREATE POLICY "Admins can create campaigns" ON notification_campaigns
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- Admins can update campaigns
CREATE POLICY "Admins can update campaigns" ON notification_campaigns
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- Admins can delete campaigns
CREATE POLICY "Admins can delete campaigns" ON notification_campaigns
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON notification_campaigns TO authenticated;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_campaigns_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER update_campaigns_updated_at
  BEFORE UPDATE ON notification_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION update_campaigns_updated_at();
