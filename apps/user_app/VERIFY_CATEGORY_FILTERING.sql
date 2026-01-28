-- ============================================================================
-- VERIFY CATEGORY FILTERING AFTER NORMALIZATION
-- Run this to verify vendors will show in their categories
-- ============================================================================

-- Step 1: Verify normalized categories
SELECT 
  'Normalized Categories' as check_type,
  category,
  COUNT(*) as vendor_count,
  STRING_AGG(business_name, ', ') as vendors
FROM vendor_profiles
WHERE category IS NOT NULL
GROUP BY category
ORDER BY category;

-- Step 2: Check if vendors have active services
SELECT 
  'Vendors with Active Services' as check_type,
  vp.category,
  vp.business_name,
  COUNT(s.id) as service_count,
  COUNT(CASE WHEN s.is_active = true AND s.is_visible_to_users = true THEN 1 END) as active_visible_services
FROM vendor_profiles vp
LEFT JOIN services s ON s.vendor_id = vp.id
WHERE vp.category IS NOT NULL
GROUP BY vp.category, vp.business_name, vp.id
ORDER BY vp.category, vp.business_name;

-- Step 3: Detailed check for Music/Dj category
SELECT 
  'Music/Dj Category Details' as check_type,
  vp.business_name,
  vp.category,
  s.name as service_name,
  s.is_active as service_active,
  s.is_visible_to_users as service_visible,
  CASE 
    WHEN s.is_active = true AND s.is_visible_to_users = true THEN '✅ Will show in app'
    ELSE '❌ Will NOT show'
  END as visibility_status
FROM vendor_profiles vp
LEFT JOIN services s ON s.vendor_id = vp.id
WHERE vp.category = 'Music/Dj'
ORDER BY vp.business_name, s.name;

-- Step 4: Check all categories match home screen
SELECT 
  'Category Match Check' as check_type,
  vp.category as database_category,
  CASE 
    WHEN vp.category IN ('Photography', 'Decoration', 'Catering', 'Venue', 'Farmhouse', 'Music/Dj', 'Essentials') 
    THEN '✅ Matches home screen'
    ELSE '⚠️ Not in home screen list'
  END as match_status,
  COUNT(*) as vendor_count
FROM vendor_profiles vp
WHERE vp.category IS NOT NULL
GROUP BY vp.category
ORDER BY vp.category;

-- ============================================================================
-- EXPECTED RESULTS
-- ============================================================================

-- After normalization:
-- - Music/Dj: 1 vendor (RDJ Music)
-- - All categories should match home screen exactly
-- - Vendors should have active, visible services

-- ============================================================================
-- IF VENDORS DON'T SHOW IN APP
-- ============================================================================

-- Check:
-- 1. Services are active: is_active = true
-- 2. Services are visible: is_visible_to_users = true
-- 3. App was restarted after normalization
-- 4. Check app console logs for errors
