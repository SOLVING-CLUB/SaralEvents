-- Update FAQs Schema to add app_type field
-- This allows separating FAQs for User App and Vendor App

-- Add app_type column if it doesn't exist
ALTER TABLE faqs 
ADD COLUMN IF NOT EXISTS app_type TEXT NOT NULL DEFAULT 'user_app' 
CHECK (app_type IN ('user_app', 'vendor_app'));

-- Create index for app_type
CREATE INDEX IF NOT EXISTS idx_faqs_app_type ON faqs(app_type);

-- Update existing FAQs to be user_app by default (if any exist)
UPDATE faqs SET app_type = 'user_app' WHERE app_type IS NULL;
