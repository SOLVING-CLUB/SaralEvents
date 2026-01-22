-- Add missing KYC fields used by the vendor app
ALTER TABLE vendor_profiles
ADD COLUMN IF NOT EXISTS aadhaar_number TEXT,
ADD COLUMN IF NOT EXISTS branch_name TEXT;

-- Refresh PostgREST cache to pick up new columns
NOTIFY pgrst, 'reload schema';
