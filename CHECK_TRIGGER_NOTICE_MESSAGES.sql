-- ============================================================================
-- CHECK: Trigger NOTICE Messages and Results
-- ============================================================================

-- Step 1: Check pg_net queue for notification requests
-- If trigger fired, there should be requests here
SELECT 
  '🔍 pg_net Queue - Notification Requests' as check_type,
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
LIMIT 30;

-- Step 3: Check if simple test trigger exists
SELECT 
  'Simple Test Trigger Status' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  CASE 
    WHEN trigger_name IS NOT NULL THEN '✅ Test trigger exists'
    ELSE '❌ Test trigger not found'
  END as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'test_simple_payment_trigger';

-- Step 4: Check payment status after updates
SELECT 
  'Payment Status After Test' as check_type,
  id,
  status,
  updated_at
FROM payment_milestones
WHERE id = 'fc3ab4fb-bede-470e-aff7-c93a61161e1c';
