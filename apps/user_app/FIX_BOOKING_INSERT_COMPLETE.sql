-- =============================================================================
-- COMPLETE FIX FOR BOOKING INSERT ISSUE
-- Copy and run this ENTIRE script in Supabase SQL Editor
-- =============================================================================

-- STEP 1: Show recent drafts (to verify draft exists with booking_date)
SELECT 'STEP 1: Recent drafts' as step;
SELECT 
    id as draft_id,
    service_id,
    vendor_id,
    booking_date,
    event_date,
    status,
    created_at
FROM booking_drafts
ORDER BY created_at DESC
LIMIT 5;

-- STEP 2: Show recent bookings (to see if any were created)
SELECT 'STEP 2: Recent bookings' as step;
SELECT 
    id as booking_id,
    user_id,
    service_id,
    vendor_id,
    booking_date,
    status,
    milestone_status,
    created_at
FROM bookings
ORDER BY created_at DESC
LIMIT 10;

-- STEP 3: Check constraints on bookings table
SELECT 'STEP 3: Check constraints' as step;
SELECT
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.bookings'::regclass
AND contype = 'c';

-- STEP 4: Ensure INSERT policy exists (drop and recreate)
SELECT 'STEP 4: Fixing INSERT policy' as step;
DROP POLICY IF EXISTS "Users can create their own bookings" ON bookings;
CREATE POLICY "Users can create their own bookings" ON bookings
    FOR INSERT 
    WITH CHECK (user_id = auth.uid() AND auth.uid() IS NOT NULL);

-- STEP 5: Ensure all CRUD policies exist
DROP POLICY IF EXISTS "Users can view their own bookings" ON bookings;
CREATE POLICY "Users can view their own bookings" ON bookings
    FOR SELECT 
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own bookings" ON bookings;
CREATE POLICY "Users can update their own bookings" ON bookings
    FOR UPDATE 
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Vendors can view bookings for their services" ON bookings;
CREATE POLICY "Vendors can view bookings for their services" ON bookings
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM services s 
            WHERE s.id = bookings.service_id 
            AND s.vendor_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Vendors can update booking status for their services" ON bookings;
CREATE POLICY "Vendors can update booking status for their services" ON bookings
    FOR UPDATE 
    USING (
        EXISTS (
            SELECT 1 FROM services s 
            WHERE s.id = bookings.service_id 
            AND s.vendor_id = auth.uid()
        )
    );

-- STEP 6: Grant all necessary permissions
GRANT SELECT, INSERT, UPDATE ON bookings TO authenticated;

-- STEP 7: Show current policies (verify fix)
SELECT 'STEP 7: Current policies on bookings' as step;
SELECT 
    policyname,
    cmd,
    with_check
FROM pg_policies
WHERE tablename = 'bookings';

-- STEP 8: Get a valid service_id and vendor_id for testing
SELECT 'STEP 8: Available services for test' as step;
SELECT 
    s.id as service_id,
    s.vendor_id,
    s.name as service_name
FROM services s
WHERE s.is_active = true
LIMIT 3;

-- =============================================================================
-- STEP 9: TEST INSERT (uncomment and replace IDs to test)
-- =============================================================================
-- Get your user_id first by running this in the app or checking auth.users:
-- SELECT id, email FROM auth.users ORDER BY created_at DESC LIMIT 5;

-- Then uncomment and run this (replace the UUIDs):
/*
INSERT INTO bookings (
    user_id,
    service_id,
    vendor_id,
    booking_date,
    amount,
    status,
    milestone_status,
    vendor_accepted_at
)
SELECT 
    (SELECT id FROM auth.users WHERE email = 'YOUR_EMAIL_HERE' LIMIT 1),
    'PASTE_SERVICE_ID_HERE'::uuid,
    'PASTE_VENDOR_ID_HERE'::uuid,
    CURRENT_DATE + 7,
    5000.00,
    'confirmed',
    'accepted',
    NOW()
RETURNING *;
*/

-- =============================================================================
-- SUMMARY
-- =============================================================================
SELECT 'COMPLETE: All policies fixed. Check results above.' as summary;
SELECT 'If bookings still show 0 rows, the issue is in the Flutter app (draft not created or error during insert).' as note;
SELECT 'Check Flutter console for ERROR messages after payment.' as action;

