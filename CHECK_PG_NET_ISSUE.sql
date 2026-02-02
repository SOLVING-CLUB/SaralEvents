-- ============================================================================
-- CHECK PG_NET ISSUE - Why requests aren't reaching edge function
-- ============================================================================

-- Step 1: Check if pg_net extension is enabled
SELECT 
  'pg_net Extension' as check_type,
  extname,
  extversion
FROM pg_extension
WHERE extname = 'pg_net';

-- Step 2: Test pg_net with a simple external URL
-- This will tell us if pg_net works at all
DO $$
DECLARE
  v_test_id BIGINT;
BEGIN
  v_test_id := net.http_post(
    url := 'https://httpbin.org/post',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('test', 'pg_net_works')
  );
  
  RAISE NOTICE '✅ pg_net test request ID: %', v_test_id;
  RAISE NOTICE '⚠️ Check httpbin.org/post to see if request was received';
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '❌ pg_net test failed: %', SQLERRM;
END $$;

-- Step 3: Check all recent pg_net requests
SELECT 
  'Recent pg_net Requests' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 10;

-- Step 4: Check if there are any requests to send-push-notification
SELECT 
  'Notification Requests' as check_type,
  id,
  url,
  method,
  headers
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 5;
