-- Check User ID Mismatch Issue
-- Run these queries to diagnose the problem

-- 1. Get your actual user ID from auth.users (replace with your email)
SELECT id, email, created_at 
FROM auth.users 
ORDER BY created_at DESC;

-- 2. Check all bookings and their user_ids
SELECT 
    id,
    user_id,
    booking_date,
    status,
    amount,
    created_at
FROM bookings
ORDER BY created_at DESC;

-- 3. Check if bookings exist for a specific user_id
-- Replace '62a201d9-ec45-4532-ace0-825152934451' with your actual user ID
SELECT COUNT(*) as booking_count
FROM bookings
WHERE user_id = '62a201d9-ec45-4532-ace0-825152934451';

-- 4. If you need to update bookings to match your current user_id:
-- First, get your correct user ID from query 1, then:
-- UPDATE bookings 
-- SET user_id = 'YOUR_CORRECT_USER_ID'
-- WHERE user_id = '62a201d9-ec45-4532-ace0-825152934451';

-- 5. Test RLS with a specific user_id (replace with your actual user ID)
-- This simulates what the app should see:
SET LOCAL request.jwt.claim.sub = 'YOUR_USER_ID';
SELECT COUNT(*) as visible_bookings
FROM bookings
WHERE user_id = 'YOUR_USER_ID';

