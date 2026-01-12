-- Fix Booking INSERT Policy
-- This ensures users can insert bookings after payment
-- Run this in Supabase SQL Editor

-- ============================================================================
-- STEP 1: Check current INSERT policies
-- ============================================================================
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'bookings'
AND cmd = 'INSERT';

-- ============================================================================
-- STEP 2: Drop existing INSERT policy if it exists
-- ============================================================================
DROP POLICY IF EXISTS "Users can create their own bookings" ON bookings;

-- ============================================================================
-- STEP 3: Create INSERT policy with explicit check
-- ============================================================================
CREATE POLICY "Users can create their own bookings" ON bookings
    FOR INSERT 
    WITH CHECK (
        -- Ensure user_id matches authenticated user
        user_id = auth.uid()
        AND auth.uid() IS NOT NULL
    );

-- ============================================================================
-- STEP 4: Verify the policy was created
-- ============================================================================
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'bookings'
AND cmd = 'INSERT';

-- ============================================================================
-- STEP 5: Check if RLS is enabled
-- ============================================================================
SELECT 
    tablename, 
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'bookings';

-- ============================================================================
-- STEP 6: Ensure RLS is enabled (it should be)
-- ============================================================================
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 7: Grant INSERT permission to authenticated role
-- ============================================================================
GRANT INSERT ON bookings TO authenticated;

-- ============================================================================
-- STEP 8: Verify permissions
-- ============================================================================
SELECT 
    grantee,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
AND table_name = 'bookings'
AND grantee = 'authenticated'
AND privilege_type = 'INSERT';

