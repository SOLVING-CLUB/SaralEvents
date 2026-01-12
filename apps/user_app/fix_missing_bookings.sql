-- Fix Missing Bookings - Check and Repair Data
-- This script helps identify why bookings aren't showing and fixes common issues

-- ============================================================================
-- STEP 1: Check if bookings exist for your user
-- ============================================================================
-- Run this query first to see if bookings exist:
-- SELECT COUNT(*) as total_bookings FROM bookings WHERE user_id = auth.uid();

-- ============================================================================
-- STEP 2: Check for bookings with missing service_id or vendor_id
-- ============================================================================
-- These bookings won't show up in the function due to JOIN failures
SELECT 
    id,
    user_id,
    service_id,
    vendor_id,
    booking_date,
    status,
    amount,
    created_at,
    CASE 
        WHEN service_id IS NULL THEN 'MISSING SERVICE_ID'
        WHEN vendor_id IS NULL THEN 'MISSING VENDOR_ID'
        ELSE 'OK'
    END as issue
FROM bookings
WHERE user_id = auth.uid()
AND (service_id IS NULL OR vendor_id IS NULL);

-- ============================================================================
-- STEP 3: Check if services exist for bookings
-- ============================================================================
SELECT 
    b.id as booking_id,
    b.service_id,
    CASE WHEN s.id IS NULL THEN 'SERVICE NOT FOUND' ELSE 'OK' END as service_status,
    s.name as service_name
FROM bookings b
LEFT JOIN services s ON b.service_id = s.id
WHERE b.user_id = auth.uid()
AND s.id IS NULL;

-- ============================================================================
-- STEP 4: Check if vendor_profiles exist for bookings
-- ============================================================================
SELECT 
    b.id as booking_id,
    b.vendor_id,
    CASE WHEN vp.id IS NULL THEN 'VENDOR NOT FOUND' ELSE 'OK' END as vendor_status,
    vp.business_name as vendor_name
FROM bookings b
LEFT JOIN vendor_profiles vp ON b.vendor_id = vp.id
WHERE b.user_id = auth.uid()
AND vp.id IS NULL;

-- ============================================================================
-- STEP 5: Test the function with detailed error checking
-- ============================================================================
-- This will show you exactly what the function returns:
DO $$
DECLARE
    result_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO result_count
    FROM get_user_bookings(auth.uid());
    
    RAISE NOTICE 'Function returned % bookings', result_count;
END $$;

-- ============================================================================
-- STEP 6: Direct query to see all bookings (bypassing function)
-- ============================================================================
-- This shows what SHOULD be visible:
SELECT 
    b.id,
    b.booking_date,
    b.status,
    b.amount,
    COALESCE(s.name, 'MISSING SERVICE') as service_name,
    COALESCE(vp.business_name, 'MISSING VENDOR') as vendor_name,
    b.created_at
FROM bookings b
LEFT JOIN services s ON b.service_id = s.id
LEFT JOIN vendor_profiles vp ON b.vendor_id = vp.id
WHERE b.user_id = auth.uid()
ORDER BY b.created_at DESC;

-- ============================================================================
-- STEP 7: Fix bookings with missing service_id (if any)
-- ============================================================================
-- If you have bookings with NULL service_id, you'll need to manually fix them
-- or delete them if they're invalid:
-- UPDATE bookings SET service_id = '<correct-service-id>' WHERE id = '<booking-id>' AND service_id IS NULL;
-- OR
-- DELETE FROM bookings WHERE service_id IS NULL AND user_id = auth.uid();

-- ============================================================================
-- STEP 8: Fix bookings with missing vendor_id (if any)
-- ============================================================================
-- If you have bookings with NULL vendor_id, get it from the service:
-- UPDATE bookings b
-- SET vendor_id = (SELECT vendor_id FROM services WHERE id = b.service_id)
-- WHERE b.vendor_id IS NULL 
-- AND b.service_id IS NOT NULL
-- AND b.user_id = auth.uid();

-- ============================================================================
-- STEP 9: Verify RLS policies allow viewing
-- ============================================================================
-- Check if you can see your bookings directly:
SELECT COUNT(*) as visible_bookings
FROM bookings
WHERE user_id = auth.uid();

-- If this returns 0 but STEP 1 returned > 0, there's an RLS issue
-- If both return the same, the issue is with the function or JOINs

