-- Comprehensive Fix for Bookings Visibility Issue
-- This script fixes RLS policies, function permissions, and ensures bookings are visible after payment

-- ============================================================================
-- 1. DROP ALL EXISTING POLICIES TO AVOID CONFLICTS
-- ============================================================================

-- Drop all existing policies on bookings table
DROP POLICY IF EXISTS "Users can view their own bookings" ON bookings;
DROP POLICY IF EXISTS "Users can create their own bookings" ON bookings;
DROP POLICY IF EXISTS "Users can update their own bookings" ON bookings;
DROP POLICY IF EXISTS "Vendors can view bookings for their services" ON bookings;
DROP POLICY IF EXISTS "Vendors can update booking status for their services" ON bookings;

-- Drop all existing policies on services table (if they interfere)
DROP POLICY IF EXISTS "Anonymous users can view active services" ON services;
DROP POLICY IF EXISTS "Anonymous users can view active and visible services" ON services;

-- Drop all existing policies on vendor_profiles table (if they interfere)
DROP POLICY IF EXISTS "Public can view vendor profiles" ON vendor_profiles;
DROP POLICY IF EXISTS "Users can view vendor profiles" ON vendor_profiles;

-- ============================================================================
-- 2. RECREATE RLS POLICIES FOR BOOKINGS TABLE
-- ============================================================================

-- Users can view their own bookings (MUST BE FIRST - most permissive for users)
CREATE POLICY "Users can view their own bookings" ON bookings
    FOR SELECT 
    USING (auth.uid() = user_id);

-- Users can create their own bookings
CREATE POLICY "Users can create their own bookings" ON bookings
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own bookings
CREATE POLICY "Users can update their own bookings" ON bookings
    FOR UPDATE 
    USING (auth.uid() = user_id);

-- Vendors can view bookings for their services
CREATE POLICY "Vendors can view bookings for their services" ON bookings
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM services s 
            WHERE s.id = bookings.service_id 
            AND s.vendor_id = auth.uid()
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
        )
    );

-- ============================================================================
-- 3. ENSURE SERVICES TABLE HAS PROPER RLS POLICIES
-- ============================================================================

-- Ensure services table has visibility column
ALTER TABLE services ADD COLUMN IF NOT EXISTS is_visible_to_users BOOLEAN DEFAULT true;
UPDATE services SET is_visible_to_users = true WHERE is_visible_to_users IS NULL;

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Authenticated users can view active services" ON services;
DROP POLICY IF EXISTS "Anonymous users can view active services" ON services;
DROP POLICY IF EXISTS "Anonymous users can view active and visible services" ON services;

-- Allow authenticated users to view services (needed for get_user_bookings function)
CREATE POLICY "Authenticated users can view active services" ON services
    FOR SELECT 
    USING (is_active = true AND is_visible_to_users = true);

-- ============================================================================
-- 4. ENSURE VENDOR_PROFILES TABLE HAS PROPER RLS POLICIES
-- ============================================================================

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Authenticated users can view vendor profiles" ON vendor_profiles;
DROP POLICY IF EXISTS "Public can view vendor profiles" ON vendor_profiles;
DROP POLICY IF EXISTS "Users can view vendor profiles" ON vendor_profiles;

-- Allow authenticated users to view vendor profiles (needed for get_user_bookings function)
CREATE POLICY "Authenticated users can view vendor profiles" ON vendor_profiles
    FOR SELECT 
    USING (true); -- Allow all authenticated users to view vendor profiles

-- ============================================================================
-- 5. RECREATE get_user_bookings FUNCTION WITH PROPER PERMISSIONS
-- ============================================================================

-- Drop and recreate the function to ensure it has proper permissions
DROP FUNCTION IF EXISTS get_user_bookings(UUID);

CREATE OR REPLACE FUNCTION get_user_bookings(user_uuid UUID)
RETURNS TABLE (
    booking_id UUID,
    service_name TEXT,
    vendor_name TEXT,
    booking_date DATE,
    booking_time TIME,
    status TEXT,
    amount DECIMAL(10,2),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) 
LANGUAGE plpgsql
SECURITY DEFINER -- Run with creator's privileges to bypass RLS
SET search_path = public
AS $$
DECLARE
    booking_record RECORD;
    service_name_val TEXT;
    vendor_name_val TEXT;
BEGIN
    -- Verify the user_uuid matches the authenticated user
    IF user_uuid != auth.uid() THEN
        RAISE EXCEPTION 'User UUID mismatch';
    END IF;

    -- Loop through bookings and fetch service/vendor names separately
    -- This avoids JOIN issues with RLS policies
    FOR booking_record IN 
        SELECT 
            b.id,
            b.service_id,
            b.vendor_id,
            b.booking_date,
            b.booking_time,
            b.status,
            b.amount,
            b.notes,
            b.created_at
        FROM bookings b
        WHERE b.user_id = user_uuid
        ORDER BY b.created_at DESC
    LOOP
        -- Get service name (with error handling)
        BEGIN
            SELECT name INTO service_name_val
            FROM services
            WHERE id = booking_record.service_id
            LIMIT 1;
        EXCEPTION WHEN OTHERS THEN
            service_name_val := 'Unknown Service';
        END;
        
        -- Default if NULL
        IF service_name_val IS NULL THEN
            service_name_val := 'Unknown Service';
        END IF;

        -- Get vendor name (with error handling)
        BEGIN
            SELECT business_name INTO vendor_name_val
            FROM vendor_profiles
            WHERE id = booking_record.vendor_id
            LIMIT 1;
        EXCEPTION WHEN OTHERS THEN
            vendor_name_val := 'Unknown Vendor';
        END;
        
        -- Default if NULL
        IF vendor_name_val IS NULL THEN
            vendor_name_val := 'Unknown Vendor';
        END IF;

        -- Return the row
        booking_id := booking_record.id;
        service_name := service_name_val;
        vendor_name := vendor_name_val;
        booking_date := booking_record.booking_date;
        booking_time := booking_record.booking_time;
        status := booking_record.status;
        amount := booking_record.amount;
        notes := booking_record.notes;
        created_at := booking_record.created_at;
        
        RETURN NEXT;
    END LOOP;
    
    RETURN;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_user_bookings(UUID) TO authenticated;

-- ============================================================================
-- 6. VERIFY BOOKINGS TABLE STRUCTURE
-- ============================================================================

-- Ensure milestone_status column exists (for escrow system)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS milestone_status TEXT DEFAULT 'created';

-- ============================================================================
-- 7. CREATE INDEXES FOR BETTER PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_service_id ON bookings(service_id);
CREATE INDEX IF NOT EXISTS idx_bookings_vendor_id ON bookings(vendor_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_created_at ON bookings(created_at DESC);

-- ============================================================================
-- 8. VERIFY NO DELETION TRIGGERS EXIST
-- ============================================================================

-- List all triggers on bookings table (for debugging)
-- SELECT trigger_name, event_manipulation, event_object_table, action_statement 
-- FROM information_schema.triggers 
-- WHERE event_object_table = 'bookings';

-- ============================================================================
-- VERIFICATION QUERIES (Run these manually to verify)
-- ============================================================================

-- Check if bookings exist:
-- SELECT COUNT(*) FROM bookings WHERE user_id = auth.uid();

-- Check if function works:
-- SELECT * FROM get_user_bookings(auth.uid());

-- Check RLS policies:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
-- FROM pg_policies 
-- WHERE tablename = 'bookings';

