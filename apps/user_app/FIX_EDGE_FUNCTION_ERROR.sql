-- ============================================================================
-- FIX "Failed to fetch" Error
-- This error means the edge function isn't deployed or URL is wrong
-- ============================================================================

-- Step 1: Check current Supabase URL in function
-- The function has hardcoded URL: https://hucsihwqsuvqvbnyapdn.supabase.co
-- Verify this is correct for your project

SELECT 
  'Current Configuration' as check_type,
  'Hardcoded URL: https://hucsihwqsuvqvbnyapdn.supabase.co' as supabase_url,
  'Edge Function URL: https://hucsihwqsuvqvbnyapdn.supabase.co/functions/v1/send-push-notification' as edge_function_url,
  '⚠️ Verify this URL matches your Supabase project' as note;

-- Step 2: Check if we can set environment variables (better than hardcoded)
-- Get your actual values from: Supabase Dashboard > Settings > API
SELECT 
  'Environment Variables Check' as check_type,
  CASE 
    WHEN current_setting('app.supabase_url', true) IS NOT NULL 
    THEN '✅ Using environment variable: ' || current_setting('app.supabase_url', true)
    ELSE '⚠️ Using hardcoded URL (set environment variable for better control)'
  END as status;

-- Step 3: Test if edge function endpoint is accessible
-- Note: This will show if the function exists (even if it returns an error)
DO $$
DECLARE
  v_url TEXT;
  v_response TEXT;
BEGIN
  -- Try to get URL from settings or use hardcoded
  v_url := COALESCE(
    current_setting('app.supabase_url', true),
    'https://hucsihwqsuvqvbnyapdn.supabase.co'
  );
  
  RAISE NOTICE 'Testing edge function at: %/functions/v1/send-push-notification', v_url;
  RAISE NOTICE '⚠️ If you see "Failed to fetch", the edge function is NOT deployed';
  RAISE NOTICE '⚠️ Deploy it using: supabase functions deploy send-push-notification';
END $$;

-- ============================================================================
-- SOLUTION: Deploy Edge Function
-- ============================================================================
-- The "Failed to fetch" error means the edge function doesn't exist or isn't accessible.
-- You need to deploy it:

-- Option 1: Using Supabase CLI (Recommended)
/*
1. Install Supabase CLI:
   npm install -g supabase

2. Login:
   supabase login

3. Link to your project:
   supabase link --project-ref hucsihwqsuvqvbnyapdn

4. Deploy the function:
   cd apps/user_app
   supabase functions deploy send-push-notification

5. Set FCM secret:
   supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="<base64_encoded_service_account_json>"
*/

-- Option 2: Using Supabase Dashboard
/*
1. Go to Supabase Dashboard > Edge Functions
2. Click "Create a new function"
3. Name it: send-push-notification
4. Copy code from: apps/user_app/supabase/functions/send-push-notification/index.ts
5. Deploy
6. Set secret: FCM_SERVICE_ACCOUNT_BASE64
*/

-- ============================================================================
-- VERIFY DEPLOYMENT
-- ============================================================================
-- After deploying, test again with:
-- File: apps/user_app/TEST_NOTIFICATION_NOW.sql
