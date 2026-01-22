-- ============================================================================
-- ENABLE PG_NET AND TEST
-- Run this to enable pg_net and verify it works
-- ============================================================================

-- Step 1: Enable pg_net extension
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Step 2: Verify extension is enabled
SELECT 
  'pg_net Extension Status' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
    THEN '✅ ENABLED'
    ELSE '❌ NOT ENABLED - Contact Supabase support'
  END AS status;

-- Step 3: Check if we can use net.http_post
-- Note: This will fail if pg_net is not properly enabled
DO $$
DECLARE
  v_test_id BIGINT;
BEGIN
  -- Try a simple test call
  v_test_id := net.http_post(
    url := 'https://httpbin.org/post',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('test', 'pg_net')
  );
  
  RAISE NOTICE '✅ pg_net.http_post works! Request ID: %', v_test_id;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '❌ pg_net.http_post failed: %', SQLERRM;
    RAISE NOTICE '⚠️ If pg_net is not available, you may need to:';
    RAISE NOTICE '   1. Check your Supabase plan (some plans require enabling extensions)';
    RAISE NOTICE '   2. Go to Database > Extensions in Supabase Dashboard';
    RAISE NOTICE '   3. Search for "pg_net" and click "Enable"';
END $$;
