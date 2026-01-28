-- ============================================================================
-- FIX PUSH NOTIFICATIONS FOR BOTH USER AND VENDOR APPS
-- Run this script in Supabase SQL Editor to fix push notification issues
-- ============================================================================

-- Step 1: Enable pg_net extension (required for HTTP requests from triggers)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Step 2: Add app_type column to fcm_tokens if missing
-- This column is CRITICAL for filtering tokens by app type (user_app vs vendor_app)
ALTER TABLE fcm_tokens
  ADD COLUMN IF NOT EXISTS app_type TEXT CHECK (app_type IN ('user_app','vendor_app','company_web')) DEFAULT 'user_app';

-- Step 3: Create indexes for app_type filtering (improves query performance)
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_app_type 
  ON fcm_tokens(app_type) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_app 
  ON fcm_tokens(user_id, app_type) WHERE is_active = true;

-- Step 4: Backfill app_type for existing tokens
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

-- Set app_type for any remaining NULL tokens to 'user_app' (default)
UPDATE fcm_tokens
SET app_type = 'user_app'
WHERE app_type IS NULL;

-- Step 5: Verify the updates
SELECT 
  'Token Distribution' as check_type,
  COUNT(*) as total_tokens,
  COUNT(CASE WHEN app_type = 'user_app' AND is_active = true THEN 1 END) as active_user_app_tokens,
  COUNT(CASE WHEN app_type = 'vendor_app' AND is_active = true THEN 1 END) as active_vendor_app_tokens,
  COUNT(CASE WHEN app_type IS NULL THEN 1 END) as null_app_type_tokens,
  COUNT(CASE WHEN is_active = false THEN 1 END) as inactive_tokens
FROM fcm_tokens;

-- Step 6: Check if app_type column exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'fcm_tokens' AND column_name = 'app_type'
    )
    THEN '✅ app_type column exists'
    ELSE '❌ app_type column does NOT exist'
  END AS app_type_column_status;

-- Step 7: Verify pg_net extension
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_extension WHERE extname = 'pg_net'
    )
    THEN '✅ pg_net extension enabled'
    ELSE '❌ pg_net extension NOT enabled'
  END AS pg_net_status;

-- ============================================================================
-- IMPORTANT: Environment Variables Setup
-- ============================================================================
-- You MUST set these environment variables in Supabase Dashboard:
-- 1. Go to Settings > Database > Connection Pooling
-- 2. Or use SQL Editor to run (replace with your actual values):
--
-- ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';
-- ALTER DATABASE postgres SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';
--
-- To get these values:
-- - supabase_url: Found in Supabase Dashboard > Settings > API > Project URL
-- - supabase_service_role_key: Found in Supabase Dashboard > Settings > API > service_role key (keep secret!)
--
-- ============================================================================
-- Edge Function Setup
-- ============================================================================
-- 1. Deploy the edge function: supabase/functions/send-push-notification
-- 2. Set the FCM_SERVICE_ACCOUNT_BASE64 secret:
--    supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="<base64_encoded_service_account_json>"
--
-- To get FCM Service Account:
-- 1. Go to Firebase Console > Project Settings > Service Accounts
-- 2. Click "Generate New Private Key"
-- 3. Base64 encode the JSON file:
--    - On Linux/Mac: base64 -i service-account.json
--    - On Windows: Use PowerShell: [Convert]::ToBase64String([IO.File]::ReadAllBytes("service-account.json"))
--
-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Check active tokens by app type
SELECT 
  app_type,
  COUNT(*) as token_count,
  COUNT(DISTINCT user_id) as unique_users
FROM fcm_tokens
WHERE is_active = true
GROUP BY app_type;

-- Check recent token registrations
SELECT 
  app_type,
  device_type,
  COUNT(*) as count,
  MAX(created_at) as latest_registration
FROM fcm_tokens
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY app_type, device_type
ORDER BY latest_registration DESC;
