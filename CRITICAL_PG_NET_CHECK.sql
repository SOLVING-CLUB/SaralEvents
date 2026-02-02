-- ============================================================================
-- CRITICAL CHECK: pg_net Queue Results
-- ============================================================================

-- This is THE MOST IMPORTANT check - did the trigger fire?

-- Step 1: Check for notification requests
SELECT 
  '🔍 CRITICAL: Notification Requests' as check_type,
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

-- Step 2: If no results above, show ALL requests
SELECT 
  'All pg_net Requests (Last 30)' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 30;

-- Step 3: Count total
SELECT 
  'Total pg_net Requests' as check_type,
  COUNT(*) as total_count,
  MAX(id) as latest_id,
  CASE 
    WHEN COUNT(*) = 0 THEN '❌ Queue is empty - trigger did NOT fire'
    WHEN COUNT(*) > 0 AND MAX(id) IN (SELECT id FROM net.http_request_queue WHERE url LIKE '%send-push-notification%') THEN '✅ Queue has notification requests - trigger FIRED!'
    ELSE '⚠️ Queue has requests but no notification requests'
  END as diagnosis
FROM net.http_request_queue;
