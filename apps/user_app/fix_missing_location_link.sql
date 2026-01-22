-- Fix Missing Location Link for Specific Booking
-- This script helps identify and fix bookings missing location_link

-- Step 1: Find the draft for the specific booking
SELECT 
  b.id as booking_id,
  b.booking_date,
  b.booking_time,
  b.location_link as booking_location_link,
  d.id as draft_id,
  d.location_link as draft_location_link,
  d.status as draft_status,
  d.created_at as draft_created_at,
  b.created_at as booking_created_at,
  CASE 
    WHEN d.location_link IS NOT NULL AND d.location_link != '' THEN 'DRAFT HAS LOCATION LINK'
    ELSE 'DRAFT ALSO MISSING LOCATION LINK'
  END as draft_status
FROM bookings b
LEFT JOIN booking_drafts d ON (
  b.service_id = d.service_id
  AND b.user_id = d.user_id
  AND b.booking_date = COALESCE(d.booking_date, d.event_date)
  AND (b.booking_time = d.booking_time OR (b.booking_time IS NULL AND d.booking_time IS NULL))
)
WHERE b.id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff';

-- Step 2: Update the specific booking if draft has location_link
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
  AND d.location_link != '';

-- Step 3: Verify the update
SELECT 
  id,
  booking_date,
  booking_time,
  location_link,
  updated_at
FROM bookings
WHERE id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff';

-- Step 4: Comprehensive backfill for ALL bookings missing location_link
-- This updates all bookings that are missing location_link from their drafts
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
  AND d.location_link != '';

-- Step 5: Report remaining bookings that still need location_link
-- (for categories that require it)
SELECT 
  b.id as booking_id,
  b.booking_date,
  b.booking_time,
  b.status,
  b.milestone_status,
  s.name as service_name,
  vp.category as vendor_category,
  b.created_at,
  CASE 
    WHEN vp.category IN ('Photography', 'Decoration', 'Catering', 'Music/Dj', 'Essentials') 
    THEN '⚠️ Location link REQUIRED but MISSING'
    ELSE 'ℹ️ Location link optional'
  END as location_status
FROM bookings b
INNER JOIN services s ON b.service_id = s.id
INNER JOIN vendor_profiles vp ON b.vendor_id = vp.id
WHERE b.location_link IS NULL
  AND vp.category IN ('Photography', 'Decoration', 'Catering', 'Music/Dj', 'Essentials')
ORDER BY b.created_at DESC;
