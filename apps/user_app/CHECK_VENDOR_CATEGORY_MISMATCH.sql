-- ============================================================================
-- CHECK VENDOR CATEGORY MISMATCH ISSUE
-- This helps identify why vendors aren't showing in categories
-- ============================================================================

-- Step 1: Check the specific vendor's category
SELECT 
  'Vendor Category Check' as check_type,
  vp.id,
  vp.business_name,
  vp.category,
  LOWER(vp.category) as category_lower,
  TRIM(LOWER(vp.category)) as category_normalized
FROM vendor_profiles vp
WHERE vp.id = (SELECT vendor_id FROM services WHERE vendor_id IN (
  SELECT id FROM vendor_profiles WHERE user_id = '14eca5f2-e934-4142-a721-efa9aa4f69a8'
) LIMIT 1)
OR vp.user_id = '14eca5f2-e934-4142-a721-efa9aa4f69a8';

-- Step 2: Check all vendor categories and their variations
SELECT 
  'All Vendor Categories' as check_type,
  category,
  COUNT(*) as vendor_count,
  LOWER(category) as category_lower,
  TRIM(LOWER(category)) as category_normalized
FROM vendor_profiles
WHERE category IS NOT NULL
GROUP BY category
ORDER BY category;

-- Step 3: Check services for Music/Dj category (case variations)
SELECT 
  'Services with Music/DJ Category' as check_type,
  s.id,
  s.name,
  s.category as service_category,
  vp.category as vendor_category,
  vp.business_name,
  CASE 
    WHEN LOWER(vp.category) LIKE '%music%' OR LOWER(vp.category) LIKE '%dj%' THEN '✅ Matches Music/DJ'
    ELSE '❌ Does not match'
  END as match_status
FROM services s
JOIN vendor_profiles vp ON vp.id = s.vendor_id
WHERE LOWER(vp.category) LIKE '%music%' 
   OR LOWER(vp.category) LIKE '%dj%'
   OR LOWER(vp.category) LIKE '%sound%'
ORDER BY vp.category;

-- Step 4: Check what category name is used in home screen vs database
-- Home screen uses: 'Music/Dj'
-- Check if database has: 'music/dj', 'Music/Dj', 'Music/DJ', etc.
SELECT 
  'Category Name Comparison' as check_type,
  'Home Screen' as source,
  'Music/Dj' as category_name
UNION ALL
SELECT 
  'Category Name Comparison' as check_type,
  'Database Values' as source,
  category as category_name
FROM vendor_profiles
WHERE LOWER(category) LIKE '%music%' OR LOWER(category) LIKE '%dj%'
GROUP BY category;

-- ============================================================================
-- EXPECTED ISSUE
-- ============================================================================

-- The issue is likely:
-- - Home screen passes: 'Music/Dj' (capital M, capital D)
-- - Database has: 'music/dj' (lowercase)
-- - Query uses: .eq('category', categoryName) which is case-sensitive
-- 
-- Solution: Use case-insensitive comparison or normalize category names

-- ============================================================================
-- FIX OPTIONS
-- ============================================================================

-- Option 1: Normalize category names in database (recommended)
-- UPDATE vendor_profiles 
-- SET category = 'Music/Dj'
-- WHERE LOWER(category) = 'music/dj';

-- Option 2: Update home screen to use lowercase
-- Change 'Music/Dj' to 'music/dj' in home_screen.dart

-- Option 3: Use case-insensitive query in catalog_screen.dart
-- Change .eq('category', categoryName) to use ILIKE or LOWER()
