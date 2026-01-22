-- Fix User ID Mismatch for Current User
-- Run this script in your Supabase SQL Editor to transfer bookings from the old ID to your current ID.

-- Current User ID: ad73265c-4877-4a94-8394-5c455cc2a012
-- Old User ID (Hardcoded in App): 62a201d9-ec45-4532-ace0-825152934451

UPDATE bookings
SET user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012' -- Your current ID
WHERE user_id = '62a201d9-ec45-4532-ace0-825152934451'; -- The old ID

-- Verify the update
SELECT count(*) as transferred_bookings 
FROM bookings 
WHERE user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012';
