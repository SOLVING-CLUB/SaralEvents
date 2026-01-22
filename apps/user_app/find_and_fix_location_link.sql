-- Comprehensive script to find and fix location_link for specific booking
-- Booking ID: a49ab867-a7d9-45c8-82eb-aaf734641aff

-- Step 1: Get all details about the booking
SELECT 
  '=== BOOKING DETAILS ===' as section,
  b.id,
  b.user_id,
  b.service_id,
  b.vendor_id,
  b.booking_date,
  b.booking_time,
  b.location_link,
  b.status,
  b.milestone_status,
  b.created_at,
  s.name as service_name,
  vp.category as vendor_category
FROM bookings b
INNER JOIN services s ON b.service_id = s.id
INNER JOIN vendor_profiles vp ON b.vendor_id = vp.id
WHERE b.id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff';

-- Step 2: Find ALL drafts for this user/service/date (even if status doesn't match)
SELECT 
  '=== ALL DRAFTS FOR THIS USER/SERVICE ===' as section,
  d.id as draft_id,
  d.user_id,
  d.service_id,
  d.vendor_id,
  d.booking_date,
  d.event_date,
  d.booking_time,
  d.location_link,
  d.status,
  d.created_at,
  d.updated_at,
  CASE 
    WHEN d.location_link IS NOT NULL AND d.location_link != '' THEN '✅ HAS LOCATION LINK'
    ELSE '❌ NO LOCATION LINK'
  END as location_status
FROM booking_drafts d
WHERE EXISTS (
  SELECT 1 FROM bookings b
  WHERE b.id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff'
    AND b.user_id = d.user_id
    AND b.service_id = d.service_id
)
ORDER BY d.created_at DESC;

-- Step 3: Find drafts that match by date/time (more specific match)
SELECT 
  '=== MATCHING DRAFTS BY DATE/TIME ===' as section,
  d.id as draft_id,
  d.booking_date,
  d.event_date,
  d.booking_time,
  d.location_link,
  d.status,
  CASE 
    WHEN d.location_link IS NOT NULL AND d.location_link != '' THEN '✅ CAN BE COPIED'
    ELSE '❌ CANNOT COPY (draft also missing)'
  END as can_copy
FROM booking_drafts d
INNER JOIN bookings b ON (
  b.id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff'
  AND b.service_id = d.service_id
  AND b.user_id = d.user_id
  AND b.booking_date = COALESCE(d.booking_date, d.event_date)
  AND (b.booking_time = d.booking_time OR (b.booking_time IS NULL AND d.booking_time IS NULL))
)
ORDER BY d.created_at DESC;

-- Step 4: Try to update from ANY draft that has location_link (looser matching)
UPDATE bookings b
SET location_link = d.location_link,
    updated_at = NOW()
FROM booking_drafts d
WHERE b.id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff'
  AND b.service_id = d.service_id
  AND b.user_id = d.user_id
  AND b.location_link IS NULL
  AND d.location_link IS NOT NULL
  AND d.location_link != ''
RETURNING 
  b.id,
  b.location_link,
  '✅ UPDATED FROM DRAFT' as status,
  d.id as source_draft_id;

-- Step 5: If no draft had location_link, check orders table items_json
-- (Note: locationLink might be in the JSON if it was saved there)
SELECT 
  '=== CHECKING ORDERS TABLE ===' as section,
  o.id,
  o.user_id,
  o.items_json,
  o.created_at
FROM orders o
WHERE EXISTS (
  SELECT 1 FROM bookings b
  WHERE b.id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff'
    AND b.user_id = o.user_id
    AND o.created_at::date = b.created_at::date
)
ORDER BY o.created_at DESC
LIMIT 3;

-- Step 6: Final verification
SELECT 
  '=== FINAL BOOKING STATUS ===' as section,
  id,
  booking_date,
  booking_time,
  location_link,
  updated_at,
  CASE 
    WHEN location_link IS NOT NULL AND location_link != '' THEN '✅ FIXED'
    ELSE '❌ STILL MISSING - NEEDS MANUAL UPDATE'
  END as status
FROM bookings
WHERE id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff';

-- Step 7: Manual update template (if location_link needs to be added manually)
-- UNCOMMENT AND RUN THIS IF YOU HAVE THE LOCATION LINK TO ADD:
/*
UPDATE bookings
SET location_link = 'PASTE_GOOGLE_MAPS_LINK_HERE',
    updated_at = NOW()
WHERE id = 'a49ab867-a7d9-45c8-82eb-aaf734641aff';
*/
