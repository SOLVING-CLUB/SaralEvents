-- ============================================================================
-- FINAL TEST: Payment Trigger After Removing WHEN Clause
-- ============================================================================

-- Step 1: Check pg_net queue BEFORE update
SELECT 
  'Before Update - pg_net Queue Count' as check_type,
  COUNT(*) as request_count,
  MAX(id) as latest_id
FROM net.http_request_queue;

-- Step 2: Update the pending payment to trigger notification
-- This should now fire the trigger since we removed the WHEN clause
UPDATE payment_milestones
SET status = 'held_in_escrow',
    updated_at = NOW()
WHERE id = 'fc3ab4fb-bede-470e-aff7-c93a61161e1c';

-- Step 3: Wait a moment for async processing
SELECT pg_sleep(2);

-- Step 4: Check pg_net queue AFTER update
SELECT 
  '🔍 After Update - pg_net Queue' as check_type,
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

-- Step 5: Show ALL recent pg_net requests
SELECT 
  'All Recent pg_net Requests' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 20;

-- Step 6: Count total requests after update
SELECT 
  'After Update - Total pg_net Requests' as check_type,
  COUNT(*) as total_count,
  MAX(id) as latest_id
FROM net.http_request_queue;

-- Step 7: Verify payment was updated
SELECT 
  'Payment Update Verification' as check_type,
  id,
  status,
  updated_at,
  CASE 
    WHEN status = 'held_in_escrow' THEN '✅ Updated successfully'
    ELSE '❌ Update failed'
  END as update_status
FROM payment_milestones
WHERE id = 'fc3ab4fb-bede-470e-aff7-c93a61161e1c';

-- Step 8: Check trigger definition to confirm WHEN clause was removed
SELECT 
  'Trigger Definition Check' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  action_condition,
  CASE 
    WHEN action_condition IS NULL THEN '✅ WHEN clause removed (condition in function)'
    ELSE '⚠️ WHEN clause still present: ' || action_condition
  END as when_clause_status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'payment_success_notification';
