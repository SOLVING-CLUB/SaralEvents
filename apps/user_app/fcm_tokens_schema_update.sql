-- Update fcm_tokens table to support web push tokens
-- Web push tokens are stored as JSON strings containing PushSubscription object

-- Add app_type column to distinguish between user_app, vendor_app, and company_web
ALTER TABLE fcm_tokens 
ADD COLUMN IF NOT EXISTS app_type TEXT CHECK (app_type IN ('user_app', 'vendor_app', 'company_web')) DEFAULT 'user_app';

-- Update device_type to include 'web'
-- Note: This might fail if CHECK constraint exists, so we'll handle it carefully
DO $$
BEGIN
  -- Drop existing constraint if it exists
  ALTER TABLE fcm_tokens DROP CONSTRAINT IF EXISTS fcm_tokens_device_type_check;
  
  -- Add new constraint with 'web' included
  ALTER TABLE fcm_tokens ADD CONSTRAINT fcm_tokens_device_type_check 
    CHECK (device_type IN ('android', 'ios', 'web'));
END $$;

-- Create index for app_type queries
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_app_type 
  ON fcm_tokens(app_type) WHERE is_active = true;

-- Create index for user_id and app_type combination
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_app 
  ON fcm_tokens(user_id, app_type) WHERE is_active = true;

-- Update comment
COMMENT ON COLUMN fcm_tokens.token IS 'FCM token for mobile apps, or JSON string of PushSubscription for web apps';
COMMENT ON COLUMN fcm_tokens.device_type IS 'Device type: android, ios, or web';
COMMENT ON COLUMN fcm_tokens.app_type IS 'Application type: user_app, vendor_app, or company_web';
