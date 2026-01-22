-- ============================================================================
-- FIX NOTIFICATION ISSUES
-- Run this to fix common notification issues
-- ============================================================================

-- 1. Enable pg_net extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Add app_type column to fcm_tokens if missing
ALTER TABLE fcm_tokens
  ADD COLUMN IF NOT EXISTS app_type TEXT CHECK (app_type IN ('user_app','vendor_app','company_web')) DEFAULT 'user_app';

-- 3. Create indexes for app_type filtering
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_app_type ON fcm_tokens(app_type) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_app ON fcm_tokens(user_id, app_type) WHERE is_active = true;

-- 4. Backfill app_type for existing tokens
-- For vendor tokens (users who have vendor_profiles)
UPDATE fcm_tokens
SET app_type = 'vendor_app'
WHERE user_id IN (SELECT user_id FROM vendor_profiles)
  AND (app_type IS NULL OR app_type <> 'vendor_app');

-- For user tokens (users who have user_profiles but not vendor_profiles)
UPDATE fcm_tokens
SET app_type = 'user_app'
WHERE user_id IN (
  SELECT user_id FROM user_profiles
  WHERE user_id NOT IN (SELECT user_id FROM vendor_profiles)
)
  AND (app_type IS NULL OR app_type <> 'user_app');

-- 5. Set app_type for any remaining NULL tokens to 'user_app' (default)
UPDATE fcm_tokens
SET app_type = 'user_app'
WHERE app_type IS NULL;

-- 6. Verify the updates
SELECT 
  'Backfill Summary' as check_type,
  COUNT(*) as total_tokens,
  COUNT(CASE WHEN app_type = 'user_app' THEN 1 END) as user_app_tokens,
  COUNT(CASE WHEN app_type = 'vendor_app' THEN 1 END) as vendor_app_tokens,
  COUNT(CASE WHEN app_type IS NULL THEN 1 END) as null_app_type_tokens
FROM fcm_tokens;

-- 7. Note: Environment variables must be set manually
-- Run these in Supabase SQL Editor (replace with your actual values):
-- ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
-- ALTER DATABASE postgres SET app.supabase_service_role_key = 'your-service-role-key';

-- 8. Test the send_push_notification function
-- This will show a warning if environment variables are not set, but won't fail
DO $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT send_push_notification(
    '00000000-0000-0000-0000-000000000000'::UUID,
    'Test Notification',
    'This is a test to verify the function works',
    '{"type":"test"}'::JSONB,
    NULL,
    ARRAY['user_app']::TEXT[]
  ) INTO v_result;
  
  RAISE NOTICE '✅ Function test result: %', v_result;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '⚠️ Function test error: %', SQLERRM;
END $$;
