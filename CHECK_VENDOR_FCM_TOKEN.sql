-- ============================================================================
-- CHECK: Vendor FCM Token Status
-- ============================================================================

-- Step 1: Check all FCM tokens for the vendor
SELECT 
  'All FCM Tokens for Vendor' as check_type,
  ft.user_id,
  ft.app_type,
  ft.is_active,
  ft.created_at,
  ft.updated_at,
  CASE 
    WHEN ft.is_active = true THEN '✅ Active token'
    WHEN ft.is_active = false THEN '❌ Inactive token'
    ELSE 'No token'
  END as token_status
FROM fcm_tokens ft
WHERE ft.user_id = '777e7e48-388c-420e-89b9-85693197e0b7' -- Sun City Farmhouse vendor
ORDER BY ft.updated_at DESC;

-- Step 2: Check if vendor has ANY tokens (active or inactive)
SELECT 
  'Vendor Token Summary' as check_type,
  COUNT(*) as total_tokens,
  COUNT(CASE WHEN is_active = true THEN 1 END) as active_tokens,
  COUNT(CASE WHEN is_active = false THEN 1 END) as inactive_tokens,
  CASE 
    WHEN COUNT(CASE WHEN is_active = true AND app_type = 'vendor_app' THEN 1 END) > 0 THEN '✅ Has active vendor_app token'
    WHEN COUNT(CASE WHEN app_type = 'vendor_app' THEN 1 END) > 0 THEN '⚠️ Has vendor_app token but it is inactive'
    ELSE '❌ No vendor_app token'
  END as status
FROM fcm_tokens
WHERE user_id = '777e7e48-388c-420e-89b9-85693197e0b7';

-- Step 3: Check vendor profile
SELECT 
  'Vendor Profile' as check_type,
  vp.id as vendor_id,
  vp.user_id as vendor_user_id,
  vp.business_name,
  vp.email,
  CASE 
    WHEN vp.user_id IS NOT NULL THEN '✅ Has user_id'
    ELSE '❌ No user_id'
  END as user_id_status
FROM vendor_profiles vp
WHERE vp.id = 'bf25a30a-4ab6-4d2b-b879-35ceb38653a3'; -- Sun City Farmhouse

-- Step 4: Test notification (will fail if no token, but will show if function works)
SELECT 
  'Test Notification (Will fail if no token)' as check_type,
  send_push_notification(
    '777e7e48-388c-420e-89b9-85693197e0b7'::UUID,
    'Test - Vendor App',
    'Testing vendor notification',
    jsonb_build_object('type', 'test'),
    NULL,
    ARRAY['vendor_app']::TEXT[]
  ) as test_result;
