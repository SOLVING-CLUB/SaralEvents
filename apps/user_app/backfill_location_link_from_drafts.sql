-- Backfill location_link for bookings that are missing it
-- This script updates bookings with location_link from their corresponding booking_drafts
-- Only updates bookings that don't have location_link but have a matching draft with location_link

-- Step 1: Update bookings from completed drafts that have location_link
UPDATE bookings b
SET location_link = d.location_link,
    updated_at = NOW()
FROM booking_drafts d
WHERE b.service_id = d.service_id
  AND b.user_id = d.user_id
  AND b.booking_date = d.booking_date
  AND (b.booking_time = d.booking_time OR (b.booking_time IS NULL AND d.booking_time IS NULL))
  AND b.location_link IS NULL
  AND d.location_link IS NOT NULL
  AND d.location_link != ''
  AND d.status = 'completed';

-- Step 2: Also check for drafts that might have been marked as completed but booking was created separately
-- Match by service_id, user_id, booking_date, and booking_time
UPDATE bookings b
SET location_link = d.location_link,
    updated_at = NOW()
FROM booking_drafts d
WHERE b.service_id = d.service_id
  AND b.user_id = d.user_id
  AND b.booking_date = COALESCE(d.booking_date, d.event_date)
  AND (b.booking_time = d.booking_time OR (b.booking_time IS NULL AND d.booking_time IS NULL))
  AND b.location_link IS NULL
  AND d.location_link IS NOT NULL
  AND d.location_link != ''
  AND d.status IN ('completed', 'draft');

-- Step 3: Report how many bookings were updated
DO $$
DECLARE
  updated_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO updated_count
  FROM bookings b
  INNER JOIN booking_drafts d ON (
    b.service_id = d.service_id
    AND b.user_id = d.user_id
    AND b.booking_date = COALESCE(d.booking_date, d.event_date)
    AND (b.booking_time = d.booking_time OR (b.booking_time IS NULL AND d.booking_time IS NULL))
  )
  WHERE b.location_link IS NOT NULL
    AND d.location_link IS NOT NULL
    AND d.location_link != '';
  
  RAISE NOTICE 'Successfully backfilled location_link for bookings. Total bookings with location_link: %', updated_count;
END $$;

-- Step 4: Show bookings that still don't have location_link (for debugging)
SELECT 
  b.id as booking_id,
  b.booking_date,
  b.booking_time,
  b.status,
  b.milestone_status,
  s.name as service_name,
  vp.category as vendor_category,
  CASE 
    WHEN vp.category IN ('Photography', 'Decoration', 'Catering', 'Music/Dj', 'Essentials') 
    THEN 'Location link REQUIRED but MISSING'
    ELSE 'Location link optional'
  END as location_status
FROM bookings b
INNER JOIN services s ON b.service_id = s.id
INNER JOIN vendor_profiles vp ON b.vendor_id = vp.id
WHERE b.location_link IS NULL
ORDER BY b.created_at DESC
LIMIT 20;
