-- ============================================================================
-- NORMALIZE VENDOR CATEGORIES
-- This standardizes category names to match home screen expectations
-- ============================================================================

-- Step 1: Check current category variations
SELECT 
  'Current Categories' as check_type,
  category,
  COUNT(*) as vendor_count
FROM vendor_profiles
WHERE category IS NOT NULL
GROUP BY category
ORDER BY category;

-- Step 2: Normalize category names to match home screen
-- Home screen uses: 'Music/Dj' (capital M, capital D, lowercase j)
-- Database has: 'Music/DJ' (capital M, capital D, capital J)

UPDATE vendor_profiles
SET category = 'Music/Dj'
WHERE category IN ('Music/DJ', 'music/dj', 'MUSIC/DJ', 'Music/Dj', 'music/DJ');

-- Step 3: Normalize other common variations
UPDATE vendor_profiles
SET category = 'Photography'
WHERE LOWER(category) = 'photography';

UPDATE vendor_profiles
SET category = 'Decoration'
WHERE LOWER(category) = 'decoration';

UPDATE vendor_profiles
SET category = 'Catering'
WHERE LOWER(category) = 'catering';

UPDATE vendor_profiles
SET category = 'Venue'
WHERE LOWER(category) = 'venue';

UPDATE vendor_profiles
SET category = 'Farmhouse'
WHERE LOWER(category) = 'farmhouse';

UPDATE vendor_profiles
SET category = 'Essentials'
WHERE LOWER(category) = 'essentials';

-- Step 4: Verify normalization
SELECT 
  'After Normalization' as check_type,
  category,
  COUNT(*) as vendor_count
FROM vendor_profiles
WHERE category IS NOT NULL
GROUP BY category
ORDER BY category;

-- ============================================================================
-- EXPECTED RESULT
-- ============================================================================

-- All categories should now match home screen exactly:
-- - Photography
-- - Decoration
-- - Catering
-- - Venue
-- - Farmhouse
-- - Music/Dj (not Music/DJ)
-- - Essentials

-- ============================================================================
-- ALTERNATIVE: Update Home Screen Instead
-- ============================================================================

-- If you prefer to keep database as 'Music/DJ', update home_screen.dart:
-- Change line 61 from: 'name': 'Music/Dj',
-- To: 'name': 'Music/DJ',

-- But normalization is recommended for consistency
