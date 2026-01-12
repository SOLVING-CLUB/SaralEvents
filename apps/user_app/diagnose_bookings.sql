-- Diagnostic Queries to Check Why Bookings Aren't Showing
-- Run these queries one by one to diagnose the issue

-- 1. Check if bookings exist for your user
-- Replace 'YOUR_USER_ID' with your actual user ID from auth.users
SELECT 
    b.id,
    b.user_id,
    b.service_id,
    b.vendor_id,
    b.booking_date,
    b.status,
    b.amount,
    b.created_at,
    s.name as service_name,
    vp.business_name as vendor_name
FROM bookings b
LEFT JOIN services s ON b.service_id = s.id
LEFT JOIN vendor_profiles vp ON b.vendor_id = vp.id
WHERE b.user_id = auth.uid()
ORDER BY b.created_at DESC;

-- 2. Check if services exist for those bookings
SELECT 
    b.id as booking_id,
    b.service_id,
    s.id as service_exists,
    s.name as service_name,
    s.vendor_id as service_vendor_id,
    b.vendor_id as booking_vendor_id
FROM bookings b
LEFT JOIN services s ON b.service_id = s.id
WHERE b.user_id = auth.uid();

-- 3. Check if vendor_profiles exist for those bookings
SELECT 
    b.id as booking_id,
    b.vendor_id,
    vp.id as vendor_exists,
    vp.business_name as vendor_name
FROM bookings b
LEFT JOIN vendor_profiles vp ON b.vendor_id = vp.id
WHERE b.user_id = auth.uid();

-- 4. Test the get_user_bookings function directly
SELECT * FROM get_user_bookings(auth.uid());

-- 5. Check RLS policies on bookings table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'bookings'
ORDER BY policyname;

-- 6. Check if RLS is enabled
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('bookings', 'services', 'vendor_profiles');

-- 7. Check for any NULL values that might break JOINs
SELECT 
    COUNT(*) as total_bookings,
    COUNT(service_id) as bookings_with_service_id,
    COUNT(vendor_id) as bookings_with_vendor_id,
    COUNT(CASE WHEN service_id IS NULL THEN 1 END) as missing_service_id,
    COUNT(CASE WHEN vendor_id IS NULL THEN 1 END) as missing_vendor_id
FROM bookings
WHERE user_id = auth.uid();

