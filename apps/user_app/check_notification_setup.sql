-- ============================================================================
-- SIMPLIFIED NOTIFICATION SETUP CHECK
-- Run this to quickly identify what's missing
-- ============================================================================

-- 1. Check pg_net extension
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
    THEN '✅ pg_net is enabled'
    ELSE '❌ pg_net is NOT enabled - Run: CREATE EXTENSION IF NOT EXISTS pg_net;'
  END AS pg_net_status;

-- 2. Check environment variables
SELECT 
  CASE 
    WHEN current_setting('app.supabase_url', true) IS NOT NULL 
    THEN '✅ app.supabase_url is set'
    ELSE '❌ app.supabase_url is NOT set'
  END AS url_status,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
    THEN '✅ app.supabase_service_role_key is set'
    ELSE '❌ app.supabase_service_role_key is NOT set'
  END AS key_status;

-- 3. Check app_type column
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fcm_tokens' AND column_name = 'app_type')
    THEN '✅ app_type column exists'
    ELSE '❌ app_type column missing'
  END AS app_type_status;

-- 4. Check FCM tokens
SELECT 
  'FCM Tokens Status' as check_type,
  COUNT(*) as total_tokens,
  COUNT(CASE WHEN app_type = 'user_app' AND is_active = true THEN 1 END) as active_user_tokens,
  COUNT(CASE WHEN app_type = 'vendor_app' AND is_active = true THEN 1 END) as active_vendor_tokens,
  COUNT(CASE WHEN app_type IS NULL THEN 1 END) as null_app_type
FROM fcm_tokens;

-- 5. Check if triggers exist
SELECT 
  trigger_name,
  event_object_table,
  CASE WHEN trigger_name IS NOT NULL THEN '✅ Exists' ELSE '❌ Missing' END as status
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
)
ORDER BY trigger_name;

-- 6. Check if functions exist
SELECT 
  routine_name,
  CASE WHEN routine_name IS NOT NULL THEN '✅ Exists' ELSE '❌ Missing' END as status
FROM information_schema.routines
WHERE routine_name IN (
  'send_push_notification',
  'notify_booking_status_change',
  'notify_payment_success',
  'notify_vendor_milestone_confirmations'
)
ORDER BY routine_name;

-- 7. Test notification function (will show error if env vars not set)
DO $$
DECLARE
  v_result JSONB;
  v_url TEXT;
  v_key TEXT;
BEGIN
  v_url := current_setting('app.supabase_url', true);
  v_key := current_setting('app.supabase_service_role_key', true);
  
  IF v_url IS NULL OR v_key IS NULL THEN
    RAISE NOTICE '❌ Environment variables not set!';
    RAISE NOTICE '   Run these commands:';
    RAISE NOTICE '   ALTER DATABASE postgres SET app.supabase_url = ''https://your-project.supabase.co'';';
    RAISE NOTICE '   ALTER DATABASE postgres SET app.supabase_service_role_key = ''your-service-role-key'';';
  ELSE
    RAISE NOTICE '✅ Environment variables are set';
    
    -- Try to call the function
    SELECT send_push_notification(
      '00000000-0000-0000-0000-000000000000'::UUID,
      'Test',
      'Test notification',
      '{}'::JSONB,
      NULL,
      ARRAY['user_app']::TEXT[]
    ) INTO v_result;
    
    IF (v_result->>'success')::boolean = true THEN
      RAISE NOTICE '✅ Notification function works! Result: %', v_result;
    ELSE
      RAISE NOTICE '⚠️ Notification function returned: %', v_result;
    END IF;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '❌ Error testing function: %', SQLERRM;
END $$;

-- 8. Summary
SELECT 
  '=== SETUP SUMMARY ===' as summary,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
      AND current_setting('app.supabase_url', true) IS NOT NULL
      AND current_setting('app.supabase_service_role_key', true) IS NOT NULL
      AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fcm_tokens' AND column_name = 'app_type')
    THEN '✅ All critical components are configured!'
    ELSE '❌ Some components are missing - see details above'
  END AS overall_status;
