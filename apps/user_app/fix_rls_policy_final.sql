-- Final Fix for RLS Policy - Ensure bookings are visible
-- Run this script to fix the RLS policy issue

-- ============================================================================
-- STEP 1: Check current RLS policies
-- ============================================================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'bookings'
ORDER BY policyname;

-- ============================================================================
-- STEP 2: Drop ALL existing policies to start fresh
-- ============================================================================
DROP POLICY IF EXISTS "Users can view their own bookings" ON bookings;
DROP POLICY IF EXISTS "Users can create their own bookings" ON bookings;
DROP POLICY IF EXISTS "Users can update their own bookings" ON bookings;
DROP POLICY IF EXISTS "Vendors can view bookings for their services" ON bookings;
DROP POLICY IF EXISTS "Vendors can update booking status for their services" ON bookings;

-- ============================================================================
-- STEP 3: Recreate policies with explicit checks
-- ============================================================================

-- Users can view their own bookings
CREATE POLICY "Users can view their own bookings" ON bookings
    FOR SELECT 
    USING (
        -- Explicit check: user_id must match authenticated user
        user_id = auth.uid()
        AND auth.uid() IS NOT NULL
    );

-- Users can create their own bookings
CREATE POLICY "Users can create their own bookings" ON bookings
    FOR INSERT 
    WITH CHECK (
        -- Explicit check: user_id must match authenticated user
        user_id = auth.uid()
        AND auth.uid() IS NOT NULL
    );

-- Users can update their own bookings
CREATE POLICY "Users can update their own bookings" ON bookings
    FOR UPDATE 
    USING (
        -- Can only update if you own it
        user_id = auth.uid()
        AND auth.uid() IS NOT NULL
    )
    WITH CHECK (
        -- Can only set user_id to your own
        user_id = auth.uid()
        AND auth.uid() IS NOT NULL
    );

-- Vendors can view bookings for their services
CREATE POLICY "Vendors can view bookings for their services" ON bookings
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM services s 
            WHERE s.id = bookings.service_id 
            AND s.vendor_id = auth.uid()
            AND auth.uid() IS NOT NULL
        )
    );

-- Vendors can update booking status for their services
CREATE POLICY "Vendors can update booking status for their services" ON bookings
    FOR UPDATE 
    USING (
        EXISTS (
            SELECT 1 FROM services s 
            WHERE s.id = bookings.service_id 
            AND s.vendor_id = auth.uid()
            AND auth.uid() IS NOT NULL
        )
    );

-- ============================================================================
-- STEP 4: Verify RLS is enabled
-- ============================================================================
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 5: Test the policy (this will show 0 in SQL editor, but should work in app)
-- ============================================================================
-- Note: This will return 0 in SQL editor because auth.uid() is null there
-- But it should work in the app when authenticated
SELECT COUNT(*) as visible_bookings
FROM bookings
WHERE user_id = auth.uid();

-- ============================================================================
-- STEP 6: Check if you can see bookings with a specific user_id
-- ============================================================================
-- Replace '62a201d9-ec45-4532-ace0-825152934451' with your actual user ID
-- This simulates what the app should see when authenticated
SELECT COUNT(*) as bookings_for_user
FROM bookings
WHERE user_id = '62a201d9-ec45-4532-ace0-825152934451';

-- If this returns > 0, the bookings exist and should be visible when logged in with that user

