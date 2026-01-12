-- Verify Booking Creation - Run this to check if your booking was created correctly

-- 1. Check all bookings for your user
SELECT 
    id,
    user_id,
    service_id,
    vendor_id,
    booking_date,
    booking_time,
    status,
    amount,
    notes,
    milestone_status,
    created_at
FROM bookings
WHERE user_id = auth.uid()
ORDER BY created_at DESC;

-- 2. Check if the booking has valid service_id and vendor_id
SELECT 
    b.id as booking_id,
    b.service_id,
    b.vendor_id,
    CASE WHEN s.id IS NULL THEN 'SERVICE NOT FOUND' ELSE 'OK' END as service_check,
    CASE WHEN vp.id IS NULL THEN 'VENDOR NOT FOUND' ELSE 'OK' END as vendor_check,
    s.name as service_name,
    vp.business_name as vendor_name
FROM bookings b
LEFT JOIN services s ON b.service_id = s.id
LEFT JOIN vendor_profiles vp ON b.vendor_id = vp.id
WHERE b.user_id = auth.uid()
ORDER BY b.created_at DESC;

-- 3. Test direct query (what the app should see)
SELECT 
    b.id as booking_id,
    b.booking_date,
    b.booking_time,
    b.status,
    b.amount,
    b.notes,
    b.created_at,
    COALESCE(s.name, 'Unknown Service') as service_name,
    COALESCE(vp.business_name, 'Unknown Vendor') as vendor_name
FROM bookings b
LEFT JOIN services s ON b.service_id = s.id
LEFT JOIN vendor_profiles vp ON b.vendor_id = vp.id
WHERE b.user_id = auth.uid()
ORDER BY b.created_at DESC;

-- 4. Check RLS - Can you see your bookings?
SELECT COUNT(*) as visible_bookings
FROM bookings
WHERE user_id = auth.uid();

-- If this returns 0 but query 1 returns rows, RLS is blocking

