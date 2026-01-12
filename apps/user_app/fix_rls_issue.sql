-- Fix RLS Issue - Bookings exist but not visible
-- This script fixes the RLS policy issue

-- ============================================================================
-- STEP 1: Check if booking user_id matches your auth.uid()
-- ============================================================================
-- Run this to see the mismatch:
SELECT 
    b.id,
    b.user_id as booking_user_id,
    auth.uid() as current_auth_uid,
    CASE 
        WHEN b.user_id = auth.uid() THEN 'MATCH - Should be visible'
        ELSE 'MISMATCH - This is the problem!'
    END as status
FROM bookings b
ORDER BY b.created_at DESC
LIMIT 5;

-- ============================================================================
-- STEP 2: Check your current auth.uid()
-- ============================================================================
SELECT auth.uid() as your_user_id;

-- ============================================================================
-- STEP 3: See all bookings and their user_ids
-- ============================================================================
SELECT 
    id,
    user_id,
    service_id,
    booking_date,
    status,
    amount,
    created_at
FROM bookings
ORDER BY created_at DESC;

-- ============================================================================
-- STEP 4: Fix bookings with wrong user_id (if needed)
-- ============================================================================
-- If you find bookings with wrong user_id, update them:
-- Replace 'CORRECT_USER_ID' with your actual user ID from auth.users
-- UPDATE bookings 
-- SET user_id = 'CORRECT_USER_ID' 
-- WHERE id = 'BOOKING_ID';

-- ============================================================================
-- STEP 5: Recreate RLS policies with better error handling
-- ============================================================================

-- Drop and recreate the SELECT policy
DROP POLICY IF EXISTS "Users can view their own bookings" ON bookings;

CREATE POLICY "Users can view their own bookings" ON bookings
    FOR SELECT 
    USING (
        -- Allow if user_id matches authenticated user
        auth.uid() = user_id
        OR
        -- Allow if user is authenticated (fallback for debugging)
        (auth.uid() IS NOT NULL AND user_id = auth.uid())
    );

-- ============================================================================
-- STEP 6: Verify RLS is working
-- ============================================================================
-- After running the above, test again:
SELECT COUNT(*) as visible_bookings
FROM bookings
WHERE user_id = auth.uid();

-- This should now return the correct count

-- ============================================================================
-- STEP 7: Check if RLS is actually enabled
-- ============================================================================
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'bookings';

-- If rls_enabled is false, enable it:
-- ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

