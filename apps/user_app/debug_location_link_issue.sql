-- Debug Location Link Issue for Specific Booking
-- This script helps identify where the location_link was lost

-- Step 1: Check the booking
SELECT 
  'BOOKING' as source,
  id,
  booking_date,
  booking_time,
  location_link,
  status,
  milestone_status,
  created_at
FROM bookings
WHERE id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff';

-- Step 2: Check ALL drafts for this user/service/date combination
SELECT 
  'DRAFT' as source,
  id,
  booking_date,
  event_date,
  booking_time,
  location_link,
  status,
  created_at,
  updated_at
FROM booking_drafts d
WHERE EXISTS (
  SELECT 1 FROM bookings b
  WHERE b.id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff'
    AND b.service_id = d.service_id
    AND b.user_id = d.user_id
    AND b.booking_date = COALESCE(d.booking_date, d.event_date)
)
ORDER BY created_at DESC;

-- Step 3: Check orders table (if booking was created from payment)
-- The orders table stores items_json which might contain location_link
SELECT 
  'ORDER' as source,
  id,
  user_id,
  total_amount,
  status,
  items_json,
  created_at
FROM orders o
WHERE EXISTS (
  SELECT 1 FROM bookings b
  WHERE b.id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff'
    AND b.user_id = o.user_id
    AND o.created_at::date = b.created_at::date
)
ORDER BY created_at DESC
LIMIT 5;

-- Step 4: Check payment_milestones (might have location info)
SELECT 
  'PAYMENT_MILESTONE' as source,
  id,
  booking_id,
  milestone_type,
  amount,
  status,
  created_at
FROM payment_milestones
WHERE booking_id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff';

-- Step 5: Try to find matching draft and update booking
UPDATE bookings b
SET location_link = d.location_link,
    updated_at = NOW()
FROM booking_drafts d
WHERE b.id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff'
  AND b.service_id = d.service_id
  AND b.user_id = d.user_id
  AND b.booking_date = COALESCE(d.booking_date, d.event_date)
  AND (b.booking_time = d.booking_time OR (b.booking_time IS NULL AND d.booking_time IS NULL))
  AND b.location_link IS NULL
  AND d.location_link IS NOT NULL
  AND d.location_link != ''
RETURNING 
  b.id,
  b.location_link,
  'UPDATED' as status;

-- Step 6: Verify update
SELECT 
  id,
  booking_date,
  booking_time,
  location_link,
  updated_at
FROM bookings
WHERE id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff';
