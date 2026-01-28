# Fix: Vendor Category Filtering Issue

## 🐛 Problem

Vendors with category "music/dj" are not showing in the "Music/Dj" category in the user app.

## 🔍 Root Cause

The query in `catalog_screen.dart` was filtering by `services.category` instead of `vendor_profiles.category`. Additionally, it was using case-sensitive matching (`.eq()`) which fails when:
- Home screen passes: `'Music/Dj'` (capital M, capital D)
- Database has: `'music/dj'` (lowercase)

## ✅ Solution Applied

1. **Changed filter target:** Now filters by `vendor_profiles.category` instead of `services.category`
2. **Case-insensitive matching:** Changed from `.eq('category', categoryName)` to `.ilike('vendor_profiles.category', normalizedCategoryName)`
3. **Added category to select:** Added `category` to the vendor_profiles select to ensure it's available

## 📝 Changes Made

**File:** `apps/user_app/lib/screens/catalog_screen.dart`

**Before:**
```dart
.eq('category', categoryName)  // Wrong: filters services.category, case-sensitive
```

**After:**
```dart
.ilike('vendor_profiles.category', normalizedCategoryName)  // Correct: filters vendor_profiles.category, case-insensitive
```

## 🧪 Testing

After this fix:
1. **Go to Home Screen** → Tap "Music/Dj" category
2. **Should see:** All vendors with category containing "music" or "dj" (case-insensitive)
3. **Includes:** RDJ Music vendor and any other music/dj vendors

## 🔧 Additional Fixes Needed

If vendors still don't show, check:

1. **Category name normalization in database:**
   ```sql
   -- Check actual category values
   SELECT DISTINCT category FROM vendor_profiles 
   WHERE LOWER(category) LIKE '%music%' OR LOWER(category) LIKE '%dj%';
   ```

2. **Normalize category names (if needed):**
   ```sql
   -- Standardize to 'Music/Dj'
   UPDATE vendor_profiles 
   SET category = 'Music/Dj'
   WHERE LOWER(category) IN ('music/dj', 'music/dj', 'music/dj');
   ```

3. **Verify services are active:**
   ```sql
   -- Check if vendor's services are active
   SELECT s.*, vp.category, vp.business_name
   FROM services s
   JOIN vendor_profiles vp ON vp.id = s.vendor_id
   WHERE LOWER(vp.category) LIKE '%music%' OR LOWER(vp.category) LIKE '%dj%'
   AND s.is_active = true
   AND s.is_visible_to_users = true;
   ```

## 📊 Expected Results

- ✅ Vendors with category "music/dj" show in "Music/Dj" category
- ✅ Case-insensitive matching works (Music/Dj, music/dj, MUSIC/DJ all match)
- ✅ All active services from matching vendors are displayed

## 🎯 Status

- ✅ Code fixed: Filter now uses `vendor_profiles.category` with case-insensitive matching
- ⏳ **Ready to test:** Restart the app and check the Music/Dj category
