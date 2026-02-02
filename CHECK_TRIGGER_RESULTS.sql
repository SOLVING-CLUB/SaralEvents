-- ============================================================================
-- CHECK: Did Trigger Fire After Payment Update?
-- ============================================================================

-- Step 1: Check pg_net queue for notification requests
-- This is THE KEY check - if trigger fired, there should be a request here
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
  'Payment Update Confirmation' as check_type,
  id,
  status,
  updated_at,
  CASE 
    WHEN status = 'held_in_escrow' THEN '✅ Updated successfully'
    ELSE '❌ Update failed'
  END as update_status
FROM payment_milestones
WHERE id = '8d1f65aa-44f6-4142-9723-c60eeb23eff5';
