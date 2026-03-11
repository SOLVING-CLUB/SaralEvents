-- Create account deletion requests table
CREATE TABLE IF NOT EXISTS account_deletion_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vendor_id UUID REFERENCES vendor_profiles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    reason TEXT NOT NULL,
    suggestions TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add index for status
CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_status ON account_deletion_requests(status);

-- Enable RLS
ALTER TABLE account_deletion_requests ENABLE ROW LEVEL SECURITY;

-- Policies for account deletion requests
-- Admins can view all requests
-- Users can only see their own requests (though they likely won't see them in the vendor app)
CREATE POLICY "Admins can manage account deletion requests" ON account_deletion_requests
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    );

CREATE POLICY "Vendors can insert their own deletion requests" ON account_deletion_requests
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
    );

-- Add updated_at trigger
CREATE TRIGGER update_account_deletion_requests_updated_at BEFORE UPDATE ON account_deletion_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
