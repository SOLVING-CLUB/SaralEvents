-- ============================================================================
-- CRITICAL CHECK: Did the Trigger Actually Fire?
-- ============================================================================

-- THIS IS THE MOST IMPORTANT CHECK
-- If trigger fired, there should be a request in pg_net queue
SELECT 
  '🔍 CRITICAL: pg_net Queue Check' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅✅✅ TRIGGER FIRED - Notification request found!'
    ELSE '❌ No notification request'
  END as trigger_fired_status
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- If no results above, check ALL requests to see what's in the queue
SELECT 
  'All pg_net Requests (Last 20)' as check_type,
  id,
  url,
  method,
  CASE 
    WHEN url LIKE '%send-push-notification%' THEN '✅ Notification request'
    WHEN url LIKE '%httpbin%' THEN 'Test request'
    ELSE 'Other request'
  END as request_type
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 20;

-- Check trigger exists and is active
SELECT 
  'Trigger Status' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  '✅ ACTIVE' as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';

-- Check the function exists
SELECT 
  'Function Status' as check_type,
  routine_name,
  routine_type,
  '✅ EXISTS' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'notify_payment_success';
