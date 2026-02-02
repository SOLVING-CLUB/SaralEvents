-- ============================================================================
-- FINAL COMPREHENSIVE CHECK: Did Trigger Fire?
-- ============================================================================

-- Step 1: Check pg_net queue for notification requests
-- THIS IS THE KEY CHECK - if trigger fired, there should be requests here
SELECT 
  '🔍 KEY CHECK: pg_net Queue - Notification Requests' as check_type,
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

-- Step 2: Show ALL recent pg_net requests (last 30)
SELECT 
  'All Recent pg_net Requests (Last 30)' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 30;

-- Step 3: Count total requests and check for notification requests
SELECT 
  'Total pg_net Requests Analysis' as check_type,
  COUNT(*) as total_count,
  COUNT(CASE WHEN url LIKE '%send-push-notification%' THEN 1 END) as notification_count,
  MAX(id) as latest_id,
  CASE 
    WHEN COUNT(CASE WHEN url LIKE '%send-push-notification%' THEN 1 END) > 0 THEN '✅✅✅ TRIGGER FIRED - Notification requests found!'
    WHEN COUNT(*) = 0 THEN '❌ Queue is empty - trigger did NOT fire'
    ELSE '⚠️ Queue has requests but NO notification requests - trigger did NOT fire'
  END as diagnosis
FROM net.http_request_queue;

-- Step 4: Verify trigger is still attached
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

-- Step 5: Check if simple test trigger exists
SELECT 
  'Simple Test Trigger Status' as check_type,
  trigger_name,
  CASE 
    WHEN trigger_name IS NOT NULL THEN '✅ Test trigger exists'
    ELSE '❌ Test trigger not found'
  END as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'test_simple_payment_trigger';

-- Step 6: Check payment that was updated
SELECT 
  'Payment Update Confirmation' as check_type,
  id,
  status,
  updated_at,
  CASE 
    WHEN status = 'released' THEN '✅ Updated to released'
    ELSE 'Status: ' || status
  END as update_status
FROM payment_milestones
WHERE id = 'fc3ab4fb-bede-470e-aff7-c93a61161e1c';
