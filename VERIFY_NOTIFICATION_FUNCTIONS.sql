-- ============================================================================
-- VERIFY NOTIFICATION FUNCTIONS IMPLEMENTATION
-- Check if functions are properly implemented with appTypes filtering
-- ============================================================================

-- Step 1: Check which functions are actually used by triggers
SELECT 
  'Trigger-Function Mapping' as check_type,
  t.trigger_name,
  t.event_object_table,
  t.event_manipulation,
  pg_get_triggerdef(t.oid) as trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND t.tgname LIKE '%notification%'
ORDER BY t.tgname;

-- Step 2: Check function definitions for appTypes usage
-- This will show if functions use ARRAY['user_app'] or ARRAY['vendor_app']
SELECT 
  'Function Definitions Check' as check_type,
  routine_name,
  CASE 
    WHEN routine_definition LIKE '%ARRAY%user_app%' OR routine_definition LIKE '%ARRAY%vendor_app%' THEN '✅ Uses appTypes'
    WHEN routine_definition LIKE '%appTypes%' THEN '✅ Uses appTypes (parameter)'
    ELSE '⚠️ Check appTypes usage'
  END as apptypes_status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%notify%'
ORDER BY routine_name;

-- Step 3: Check for potential duplicate functions
-- Functions that might be doing the same thing
SELECT 
  'Potential Duplicates' as check_type,
  routine_name,
  CASE 
    WHEN routine_name = 'notify_booking_confirmation' AND EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_name = 'notify_booking_status_change'
    ) THEN '⚠️ Might duplicate notify_booking_status_change'
    WHEN routine_name = 'notify_order_cancellation' AND EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_name = 'notify_booking_status_change'
    ) THEN '⚠️ Might duplicate notify_booking_status_change (cancellation)'
    WHEN routine_name = 'notify_vendor_new_order' AND EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_name = 'notify_new_booking'
    ) THEN '⚠️ Might duplicate notify_new_booking'
    ELSE '✅ No obvious duplicate'
  END as duplicate_check
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'notify_booking_confirmation',
    'notify_order_cancellation',
    'notify_vendor_new_order'
  );

-- Step 4: Verify wallet and withdrawal functions exist and are used
SELECT 
  'Wallet/Withdrawal Functions' as check_type,
  routine_name,
  CASE 
    WHEN routine_name = 'notify_vendor_payment_released' THEN 
      CASE 
        WHEN EXISTS (
          SELECT 1 FROM pg_trigger t
          JOIN pg_proc p ON t.tgfoid = p.oid
          JOIN pg_namespace n ON p.pronamespace = n.oid
          WHERE n.nspname = 'public'
            AND p.proname = 'notify_vendor_payment_released'
            AND t.tgname = 'wallet_payment_released_notification'
        ) THEN '✅ Used by wallet_payment_released_notification trigger'
        ELSE '⚠️ Function exists but trigger might not use it'
      END
    WHEN routine_name = 'notify_vendor_withdrawal_status' THEN
      CASE 
        WHEN EXISTS (
          SELECT 1 FROM pg_trigger t
          JOIN pg_proc p ON t.tgfoid = p.oid
          JOIN pg_namespace n ON p.pronamespace = n.oid
          WHERE n.nspname = 'public'
            AND p.proname = 'notify_vendor_withdrawal_status'
            AND t.tgname = 'withdrawal_status_notification'
        ) THEN '✅ Used by withdrawal_status_notification trigger'
        ELSE '⚠️ Function exists but trigger might not use it'
      END
    ELSE 'N/A'
  END as usage_status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'notify_vendor_payment_released',
    'notify_vendor_withdrawal_status'
  );
