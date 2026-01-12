-- Test the get_user_bookings function
-- Run this query to test the function:

SELECT * FROM get_user_bookings(auth.uid());

-- If you get an error, try this alternative to see bookings directly:
SELECT 
    b.id as booking_id,
    b.booking_date,
    b.status,
    b.amount,
    b.created_at
FROM bookings b
WHERE b.user_id = auth.uid()
ORDER BY b.created_at DESC;

