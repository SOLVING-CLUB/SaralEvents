-- Test Booking Access - Run this to verify bookings are accessible
-- This helps diagnose RLS issues

-- 1. Check if you can see bookings when authenticated
-- Note: This will return 0 in SQL editor (no auth context)
-- But should work in the app
SELECT COUNT(*) as visible_with_auth
FROM bookings
WHERE user_id = auth.uid();

-- 2. Check total bookings for the specific user_id
-- Replace with the user_id from your bookings
SELECT COUNT(*) as total_for_user
FROM bookings
WHERE user_id = '62a201d9-ec45-4532-ace0-825152934451';

-- 3. List all bookings for that user (bypassing RLS with service role)
-- This shows what SHOULD be visible
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

-- 4. Verify RLS policy allows SELECT
SELECT 
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'bookings'
AND cmd = 'SELECT';

-- The policy should have: user_id = auth.uid()

