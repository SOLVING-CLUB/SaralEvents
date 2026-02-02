-- ============================================================================
-- CHECK PG_NET REQUEST QUEUE - Fixed Query
-- ============================================================================

-- Step 1: Check what columns exist in net.http_request_queue
SELECT 
  'Column Check' as check_type,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'net'
  AND table_name = 'http_request_queue'
ORDER BY ordinal_position;

-- Step 2: Check recent requests (using only columns that definitely exist)
-- Note: Different pg_net versions have different column names
SELECT 
  'Recent Requests' as check_type,
  id,
  url
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 10;

-- Step 3: Alternative - Check if pg_net extension is enabled
SELECT 
  'Extension Check' as check_type,
  extname,
  extversion
FROM pg_extension
WHERE extname = 'pg_net';

-- Step 4: Check recent notification requests (if we can identify them)
-- Look for requests to send-push-notification
SELECT 
  'Notification Requests' as check_type,
  id,
  url,
  status_code,
  error_msg,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅ Notification request'
    ELSE 'Other request'
  END as request_type
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;
