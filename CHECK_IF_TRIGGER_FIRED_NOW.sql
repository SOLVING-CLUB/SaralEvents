-- ============================================================================
-- CHECK: Did Trigger Fire After Removing WHEN Clause?
-- ============================================================================

-- Step 1: Check pg_net queue for notification requests
-- THIS IS THE KEY CHECK - if trigger fired, there should be a request here
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

-- Step 2: Show ALL recent pg_net requests
SELECT 
  'All Recent pg_net Requests' as check_type,
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

-- Step 4: Verify payment was updated
SELECT 
  'Payment Status Check' as check_type,
  id,
  status,
  updated_at
FROM payment_milestones
WHERE id = 'fc3ab4fb-bede-470e-aff7-c93a61161e1c';
