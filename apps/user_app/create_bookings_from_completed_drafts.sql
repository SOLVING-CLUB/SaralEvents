-- Create bookings from completed drafts that don't have corresponding bookings
-- Run this in Supabase SQL Editor to fix drafts that were marked completed but bookings weren't created

-- Step 1: Check completed drafts without bookings
SELECT 
    bd.id as draft_id,
    bd.user_id,
    bd.service_id,
    bd.vendor_id,
    bd.booking_date,
    bd.booking_time,
    bd.amount,
    bd.status as draft_status,
    bd.created_at as draft_created_at,
    CASE 
        WHEN b.id IS NULL THEN 'NO BOOKING'
        ELSE 'HAS BOOKING'
    END as booking_status
FROM booking_drafts bd
LEFT JOIN bookings b ON 
    b.user_id = bd.user_id 
    AND b.service_id = bd.service_id 
    AND b.booking_date = bd.booking_date
    AND ABS(b.amount - bd.amount) < 0.01  -- Allow small rounding differences
WHERE bd.status = 'completed'
ORDER BY bd.created_at DESC;

-- Step 2: Create bookings for completed drafts that don't have bookings
-- UNCOMMENT AND RUN THIS ONLY IF YOU WANT TO CREATE MISSING BOOKINGS:
/*
INSERT INTO bookings (
    user_id,
    service_id,
    vendor_id,
    booking_date,
    booking_time,
    amount,
    notes,
    status,
    milestone_status,
    created_at,
    updated_at
)
SELECT 
    bd.user_id,
    bd.service_id,
    bd.vendor_id,
    bd.booking_date,
    bd.booking_time::TIME,
    bd.amount,
    bd.notes,
    'pending' as status,
    'created' as milestone_status,
    bd.created_at,
    NOW() as updated_at
FROM booking_drafts bd
LEFT JOIN bookings b ON 
    b.user_id = bd.user_id 
    AND b.service_id = bd.service_id 
    AND b.booking_date = bd.booking_date
    AND ABS(b.amount - bd.amount) < 0.01
WHERE bd.status = 'completed'
AND b.id IS NULL  -- Only create if booking doesn't exist
RETURNING id, user_id, service_id, booking_date, amount;
*/

-- Step 3: Verify the fix
-- After running Step 2, run this to verify all completed drafts now have bookings:
/*
SELECT 
    COUNT(*) as completed_drafts,
    COUNT(b.id) as bookings_created,
    COUNT(*) - COUNT(b.id) as missing_bookings
FROM booking_drafts bd
LEFT JOIN bookings b ON 
    b.user_id = bd.user_id 
    AND b.service_id = bd.service_id 
    AND b.booking_date = bd.booking_date
    AND ABS(b.amount - bd.amount) < 0.01
WHERE bd.status = 'completed';
*/

