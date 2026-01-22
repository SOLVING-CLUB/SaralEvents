-- ============================================================================
-- QUICK FIX FOR NOTIFICATIONS NOT WORKING
-- Run this script to fix the most common issues
-- ============================================================================

-- Step 1: Enable pg_net extension
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Step 2: Add app_type column if missing
ALTER TABLE fcm_tokens
  ADD COLUMN IF NOT EXISTS app_type TEXT CHECK (app_type IN ('user_app','vendor_app','company_web')) DEFAULT 'user_app';

-- Step 3: Create indexes
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_app_type ON fcm_tokens(app_type) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_app ON fcm_tokens(user_id, app_type) WHERE is_active = true;

-- Step 4: Backfill app_type
UPDATE fcm_tokens
SET app_type = 'vendor_app'
WHERE user_id IN (SELECT user_id FROM vendor_profiles)
  AND (app_type IS NULL OR app_type <> 'vendor_app');

UPDATE fcm_tokens
SET app_type = 'user_app'
WHERE user_id IN (
  SELECT user_id FROM user_profiles
  WHERE user_id NOT IN (SELECT user_id FROM vendor_profiles)
)
  AND (app_type IS NULL OR app_type <> 'user_app');

UPDATE fcm_tokens
SET app_type = 'user_app'
WHERE app_type IS NULL;

-- Step 5: IMPORTANT - Set environment variables
-- Replace 'YOUR_PROJECT_URL' and 'YOUR_SERVICE_ROLE_KEY' with actual values
-- Get these from Supabase Dashboard > Settings > API

-- ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT_URL.supabase.co';
-- ALTER DATABASE postgres SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';

-- Step 6: Verify setup
SELECT 
  'Setup Status' as check_type,
  CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
    THEN '✅ pg_net enabled' ELSE '❌ pg_net NOT enabled' END as pg_net,
  CASE WHEN current_setting('app.supabase_url', true) IS NOT NULL 
    THEN '✅ URL set' ELSE '❌ URL NOT set' END as supabase_url,
  CASE WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
    THEN '✅ Key set' ELSE '❌ Key NOT set' END as service_key,
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fcm_tokens' AND column_name = 'app_type')
    THEN '✅ app_type column exists' ELSE '❌ app_type column missing' END as app_type_column;

-- Step 7: Check FCM tokens
SELECT 
  'FCM Tokens' as check_type,
  COUNT(*) as total,
  COUNT(CASE WHEN app_type = 'user_app' THEN 1 END) as user_app,
  COUNT(CASE WHEN app_type = 'vendor_app' THEN 1 END) as vendor_app,
  COUNT(CASE WHEN app_type IS NULL THEN 1 END) as null_type,
  COUNT(CASE WHEN is_active = true THEN 1 END) as active
FROM fcm_tokens;

-- Step 8: Test notification function (will show warning if env vars not set)
DO $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT send_push_notification(
    '00000000-0000-0000-0000-000000000000'::UUID,
    'Test',
    'Testing notification system',
    '{"type":"test"}'::JSONB,
    NULL,
    ARRAY['user_app']::TEXT[]
  ) INTO v_result;
  
  RAISE NOTICE 'Test result: %', v_result;
  
  IF (v_result->>'success')::boolean = false THEN
    RAISE WARNING '⚠️ Notification function test FAILED. Check the result above for details.';
  ELSE
    RAISE NOTICE '✅ Notification function test PASSED';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '⚠️ Function test error: %', SQLERRM;
END $$;
