-- ============================================================================
-- UPDATE PAYMENT AND SEE TRIGGER LOGS
-- ============================================================================

-- This will update the payment and show all NOTICE messages
-- Make sure to check the NOTICE messages in your SQL client!

-- Update the payment - this will trigger notify_payment_success with logging
UPDATE payment_milestones
SET status = 'held_in_escrow',
    updated_at = NOW()
WHERE id = '8d1f65aa-44f6-4142-9723-c60eeb23eff5';

-- After running the UPDATE above, check for NOTICE messages in your SQL client
-- They should appear in the messages/notices section

-- Also check pg_net queue
SELECT 
  'pg_net Queue After Update' as check_type,
  id,
  url,
  method
FROM net.http_request_queue
WHERE url LIKE '%send-push-notification%'
ORDER BY id DESC
LIMIT 10;

-- Check if payment was updated
SELECT 
  'Payment Status After Update' as check_type,
  id,
  status,
  updated_at
FROM payment_milestones
WHERE id = '8d1f65aa-44f6-4142-9723-c60eeb23eff5';
