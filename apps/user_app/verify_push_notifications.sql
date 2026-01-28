-- ============================================================================
-- VERIFY PUSH NOTIFICATIONS SETUP
-- Run this to check if push notifications are properly configured
-- ============================================================================

-- 1. Check if pg_net extension is enabled
SELECT 
  'pg_net Extension' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
    THEN '✅ Enabled'
    ELSE '❌ NOT Enabled - Run: CREATE EXTENSION IF NOT EXISTS pg_net;'
  END AS status;

-- 2. Check if app_type column exists
SELECT 
  'app_type Column' as check_type,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'fcm_tokens' AND column_name = 'app_type'
    )
    THEN '✅ Exists'
    ELSE '❌ Missing - Run fix_push_notifications.sql'
  END AS status;

-- 3. Check token distribution
SELECT 
  'Token Distribution' as check_type,
  COUNT(*) as total_tokens,
  COUNT(CASE WHEN app_type = 'user_app' AND is_active = true THEN 1 END) as active_user_app,
  COUNT(CASE WHEN app_type = 'vendor_app' AND is_active = true THEN 1 END) as active_vendor_app,
  COUNT(CASE WHEN app_type IS NULL THEN 1 END) as null_app_type,
  COUNT(CASE WHEN is_active = false THEN 1 END) as inactive
FROM fcm_tokens;

-- 4. Check recent token registrations (last 7 days)
SELECT 
  'Recent Registrations' as check_type,
  app_type,
  device_type,
  COUNT(*) as count,
  MAX(created_at) as latest
FROM fcm_tokens
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY app_type, device_type
ORDER BY latest DESC;

-- 5. Check for tokens without app_type (should be 0)
SELECT 
  'Tokens Without app_type' as check_type,
  COUNT(*) as count,
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ All tokens have app_type'
    ELSE '❌ ' || COUNT(*) || ' tokens missing app_type - Run fix_push_notifications.sql'
  END AS status
FROM fcm_tokens
WHERE app_type IS NULL;

-- 6. Check indexes
SELECT 
  'Indexes' as check_type,
  indexname as index_name,
  CASE 
    WHEN indexname LIKE '%app_type%' THEN '✅ app_type index'
    WHEN indexname LIKE '%user%' AND indexname LIKE '%app%' THEN '✅ user+app index'
    ELSE 'Other index'
  END AS index_type
FROM pg_indexes
WHERE tablename = 'fcm_tokens'
ORDER BY indexname;

-- 7. Check environment variables (if accessible)
-- Note: These might not be accessible depending on permissions
SELECT 
  'Environment Variables' as check_type,
  CASE 
    WHEN current_setting('app.supabase_url', true) IS NOT NULL 
      AND current_setting('app.supabase_url', true) != ''
    THEN '✅ supabase_url is set'
    ELSE '❌ supabase_url NOT set - Run: ALTER DATABASE postgres SET app.supabase_url = ''...'';'
  END AS supabase_url_status,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
      AND current_setting('app.supabase_service_role_key', true) != ''
    THEN '✅ supabase_service_role_key is set'
    ELSE '❌ supabase_service_role_key NOT set - Run: ALTER DATABASE postgres SET app.supabase_service_role_key = ''...'';'
  END AS service_role_key_status;

-- 8. Check notification triggers (if they exist)
SELECT 
  'Notification Triggers' as check_type,
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE '%notification%'
ORDER BY event_object_table, trigger_name;

-- 9. Summary
SELECT 
  '=== SUMMARY ===' as summary,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
      AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fcm_tokens' AND column_name = 'app_type')
      AND NOT EXISTS (SELECT 1 FROM fcm_tokens WHERE app_type IS NULL)
    THEN '✅ Push notifications setup looks good!'
    ELSE '❌ Some issues found - Review the checks above'
  END AS overall_status;
