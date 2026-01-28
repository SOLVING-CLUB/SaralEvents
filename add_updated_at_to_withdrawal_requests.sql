-- Ensure withdrawal_requests has updated_at column for admin/company web app
-- This fixes runtime errors like:
-- "Could not find the 'updated_at' column of 'withdrawal_requests' in the schema cache"

ALTER TABLE IF EXISTS withdrawal_requests
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

