-- ============================================================================
-- FIND EXACTLY WHAT'S MISSING
-- This will show you exactly what needs to be fixed
-- ============================================================================

-- 1. Check pg_net extension
SELECT 
  'pg_net Extension' as component,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') 
    THEN '✅ ENABLED'
    ELSE '❌ MISSING - Run: CREATE EXTENSION IF NOT EXISTS pg_net;'
  END AS status;

-- 2. Check environment variables
SELECT 
  'Environment Variable: app.supabase_url' as component,
  CASE 
    WHEN current_setting('app.supabase_url', true) IS NOT NULL 
    THEN '✅ SET'
    ELSE '❌ NOT SET - See instructions below'
  END AS status;

SELECT 
  'Environment Variable: app.supabase_service_role_key' as component,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
    THEN '✅ SET'
    ELSE '❌ NOT SET - See instructions below'
  END AS status;

-- 3. Check app_type column
SELECT 
  'app_type Column in fcm_tokens' as component,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fcm_tokens' AND column_name = 'app_type')
    THEN '✅ EXISTS'
    ELSE '❌ MISSING - Run: ALTER TABLE fcm_tokens ADD COLUMN IF NOT EXISTS app_type TEXT CHECK (app_type IN (''user_app'',''vendor_app'',''company_web'')) DEFAULT ''user_app'';'
  END AS status;

-- 4. Check triggers
SELECT 
  trigger_name as component,
  CASE 
    WHEN trigger_name IS NOT NULL THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END AS status
FROM information_schema.triggers
WHERE trigger_name IN (
  'booking_status_change_notification',
  'payment_success_notification',
  'milestone_confirmation_notification_vendor'
)
UNION ALL
SELECT 
  'booking_status_change_notification' as component,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'booking_status_change_notification')
    THEN '✅ EXISTS'
    ELSE '❌ MISSING - Run: apps/user_app/automated_notification_triggers.sql'
  END AS status
WHERE NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'booking_status_change_notification')
UNION ALL
SELECT 
  'payment_success_notification' as component,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'payment_success_notification')
    THEN '✅ EXISTS'
    ELSE '❌ MISSING - Run: apps/user_app/automated_notification_triggers.sql'
  END AS status
WHERE NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'payment_success_notification')
UNION ALL
SELECT 
  'milestone_confirmation_notification_vendor' as component,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'milestone_confirmation_notification_vendor')
    THEN '✅ EXISTS'
    ELSE '❌ MISSING - Run: apps/user_app/automated_notification_triggers.sql'
  END AS status
WHERE NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'milestone_confirmation_notification_vendor');

-- 5. Check functions
SELECT 
  routine_name as component,
  CASE 
    WHEN routine_name IS NOT NULL THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END AS status
FROM information_schema.routines
WHERE routine_name IN (
  'send_push_notification',
  'notify_booking_status_change',
  'notify_payment_success',
  'notify_vendor_milestone_confirmations'
)
UNION ALL
SELECT 
  'send_push_notification' as component,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'send_push_notification')
    THEN '✅ EXISTS'
    ELSE '❌ MISSING - Run: apps/user_app/automated_notification_triggers.sql'
  END AS status
WHERE NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'send_push_notification')
UNION ALL
SELECT 
  'notify_booking_status_change' as component,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'notify_booking_status_change')
    THEN '✅ EXISTS'
    ELSE '❌ MISSING - Run: apps/user_app/automated_notification_triggers.sql'
  END AS status
WHERE NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'notify_booking_status_change')
UNION ALL
SELECT 
  'notify_payment_success' as component,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'notify_payment_success')
    THEN '✅ EXISTS'
    ELSE '❌ MISSING - Run: apps/user_app/automated_notification_triggers.sql'
  END AS status
WHERE NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'notify_payment_success')
UNION ALL
SELECT 
  'notify_vendor_milestone_confirmations' as component,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'notify_vendor_milestone_confirmations')
    THEN '✅ EXISTS'
    ELSE '❌ MISSING - Run: apps/user_app/automated_notification_triggers.sql'
  END AS status
WHERE NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'notify_vendor_milestone_confirmations');

-- 6. Get your Supabase URL (for setting environment variable)
SELECT 
  'Your Supabase URL' as info,
  current_setting('app.supabase_url', true) as current_value,
  CASE 
    WHEN current_setting('app.supabase_url', true) IS NULL 
    THEN 'Get this from: Supabase Dashboard > Settings > API > Project URL'
    ELSE 'Already set'
  END AS instruction;

-- 7. Instructions for setting environment variables
SELECT 
  '=== SET ENVIRONMENT VARIABLES ===' as instruction,
  'Step 1: Get your Supabase URL from Dashboard > Settings > API' as step1,
  'Step 2: Get your service_role key from Dashboard > Settings > API > Secret keys' as step2,
  'Step 3: Run these commands (replace with your actual values):' as step3,
  'ALTER DATABASE postgres SET app.supabase_url = ''https://your-project.supabase.co'';' as command1,
  'ALTER DATABASE postgres SET app.supabase_service_role_key = ''your-service-role-key'';' as command2;
