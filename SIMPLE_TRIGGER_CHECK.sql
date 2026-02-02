-- ============================================================================
-- SIMPLE CHECK: Did Trigger Fire?
-- ============================================================================

-- Step 1: Check pg_net queue for notification requests
-- This is THE KEY check - if trigger fired, there will be a request here
SELECT 
  '🔍 KEY CHECK: pg_net Queue' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅✅✅ TRIGGER FIRED!'
    ELSE 'Other request'
  END as result
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- Step 2: If no results above, show ALL requests to see what's in queue
SELECT 
  'All pg_net Requests (Last 20)' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 20;

-- Step 3: Count total requests
SELECT 
  'Total pg_net Requests' as check_type,
  COUNT(*) as total_count,
  MAX(id) as latest_id
FROM net.http_request_queue;
