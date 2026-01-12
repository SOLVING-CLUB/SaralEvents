-- Fix User ID Mismatch for Bookings
-- This script helps diagnose and fix bookings that aren't showing up due to user_id mismatch

-- STEP 1: Check current bookings and their user_ids
-- Run this first to see what user_ids exist in bookings
SELECT 
    user_id,
    COUNT(*) as booking_count,
    MIN(created_at) as earliest_booking,
    MAX(created_at) as latest_booking
FROM bookings
GROUP BY user_id
ORDER BY booking_count DESC;

-- STEP 2: Check if there are bookings with the old user_id
-- Replace '62a201d9-ec45-4532-ace0-825152934451' with the user_id from your bookings
SELECT 
    id,
    user_id,
    booking_date,
    status,
    amount,
    created_at
FROM bookings
WHERE user_id = '62a201d9-ec45-4532-ace0-825152934451'
ORDER BY created_at DESC;

-- STEP 3: If you need to update bookings to match your current app user_id
-- IMPORTANT: Replace 'YOUR_CURRENT_USER_ID' with the actual user_id from your app
-- You can find this in the app's debug console when you open Orders -> Bookings
-- 
-- To find your current user_id:
-- 1. Open the app
-- 2. Go to Orders -> Bookings
-- 3. Check the debug console for "Authenticated user ID: [your-id]"
-- 4. Use that ID below

-- UNCOMMENT AND RUN THIS ONLY IF YOU NEED TO UPDATE BOOKINGS:
-- UPDATE bookings 
-- SET user_id = 'YOUR_CURRENT_USER_ID'  -- Replace with your actual user_id
-- WHERE user_id = '62a201d9-ec45-4532-ace0-825152934451';

-- STEP 4: Verify the update worked
-- After updating, run this to verify bookings are now accessible
-- SELECT COUNT(*) as bookings_for_new_user
-- FROM bookings
-- WHERE user_id = 'YOUR_CURRENT_USER_ID';  -- Replace with your actual user_id

-- STEP 5: Check RLS policy is correct (should already be correct)
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'bookings'
AND cmd = 'SELECT';

-- The policy should show: user_id = auth.uid() AND auth.uid() IS NOT NULL

