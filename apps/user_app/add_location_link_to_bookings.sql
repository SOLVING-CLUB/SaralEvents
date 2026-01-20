-- Add location_link column to bookings table
-- This field stores Google Maps location links for destination addresses
-- Required for categories: Photography, Decoration, Catering, Music/Dj, Essentials

ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS location_link TEXT;

-- Add comment to explain the column
COMMENT ON COLUMN bookings.location_link IS 'Google Maps location link for destination. Required for Photography, Decoration, Catering, Music/Dj, and Essentials categories.';

-- Add location_link to booking_drafts table as well
ALTER TABLE booking_drafts 
ADD COLUMN IF NOT EXISTS location_link TEXT;

COMMENT ON COLUMN booking_drafts.location_link IS 'Google Maps location link for destination. Required for Photography, Decoration, Catering, Music/Dj, and Essentials categories.';
