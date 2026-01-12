-- Update Booking Flow: Auto-confirm after payment (no vendor acceptance needed)
-- Keep vendor_accepted_at column for timestamp tracking, but auto-set it on payment
-- Run this in Supabase SQL Editor

-- Step 1: Keep vendor_accepted_at column - it will be auto-set on payment success
-- No need to drop it, just update the logic to auto-set it

-- Step 2: First, check what invalid milestone_status values exist
-- This helps diagnose the issue before fixing
SELECT 
    milestone_status,
    COUNT(*) as count
FROM bookings
WHERE milestone_status NOT IN ('accepted', 'vendor_traveling', 'vendor_arrived', 'arrival_confirmed', 'setup_completed', 'setup_confirmed', 'completed', 'cancelled')
AND milestone_status IS NOT NULL
GROUP BY milestone_status;

-- Step 2b: Update existing rows to fix data before applying constraint
-- Convert 'created' milestone_status to 'accepted' (auto-accepted on payment)
UPDATE bookings 
SET milestone_status = 'accepted'
WHERE milestone_status = 'created';

-- Step 2c: Handle any other invalid milestone_status values
-- Set them to NULL if they don't match the allowed values
UPDATE bookings 
SET milestone_status = NULL
WHERE milestone_status NOT IN ('accepted', 'vendor_traveling', 'vendor_arrived', 'arrival_confirmed', 'setup_completed', 'setup_confirmed', 'completed', 'cancelled')
AND milestone_status IS NOT NULL;

-- Step 3: Update milestone_status CHECK constraint to remove 'created' state
-- Keep 'accepted' state but it will be auto-set on payment, not by vendor
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_milestone_status_check;
ALTER TABLE bookings ADD CONSTRAINT bookings_milestone_status_check 
  CHECK (milestone_status IS NULL OR milestone_status IN (
    'accepted',          -- Auto-set on payment success (no vendor action needed)
    'vendor_traveling',  -- Vendor is traveling to location
    'vendor_arrived',    -- Vendor marked as arrived at location
    'arrival_confirmed', -- Customer confirmed vendor arrival
    'setup_completed',   -- Vendor marked setup as completed
    'setup_confirmed',   -- Customer confirmed setup completion
    'completed',         -- All milestones completed
    'cancelled'          -- Booking cancelled
  ));

-- Step 4: Update status constraint to include 'confirmed' state
-- Status flow: 'pending' (before payment) -> 'confirmed' (after payment) -> 'completed' (after task) -> or 'cancelled'
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE bookings ADD CONSTRAINT bookings_status_check 
  CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled'));

-- Step 5: Temporarily disable triggers that use auth.uid() to avoid NULL errors
-- These triggers fail when running SQL directly (no authenticated user context)
-- Drop both possible trigger names
DROP TRIGGER IF EXISTS trigger_create_booking_status_update ON bookings;
DROP TRIGGER IF EXISTS booking_status_update_trigger ON bookings;

-- Step 5b: Update bookings with milestone_status 'accepted' but status 'pending' to 'confirmed'
-- If milestone_status is 'accepted', it means payment was successful, so status should be 'confirmed'
-- This fixes the 15 bookings that have milestone_status='accepted' but status='pending'
UPDATE bookings 
SET 
  status = 'confirmed',
  vendor_accepted_at = COALESCE(vendor_accepted_at, created_at)
WHERE milestone_status = 'accepted' 
AND status = 'pending';

-- Step 5c: Ensure vendor_accepted_at is set for confirmed/completed bookings that don't have it
-- Trigger is still disabled, so this update won't trigger status update inserts
UPDATE bookings 
SET vendor_accepted_at = COALESCE(vendor_accepted_at, created_at)
WHERE status IN ('confirmed', 'completed')
AND vendor_accepted_at IS NULL;

-- Step 5d: Re-enable the trigger after all updates are complete
-- The trigger will work normally when updates come from the app (with authenticated users)
CREATE TRIGGER booking_status_update_trigger
    AFTER UPDATE ON bookings
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION create_booking_status_update();

-- Step 7: Update order_notifications to keep vendor_accepted notification type
-- (It will be sent automatically on payment, not when vendor accepts)
-- Keep the notification type but update the logic in the app

-- Step 8: Verify the changes
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'bookings'
AND column_name IN ('vendor_accepted_at', 'milestone_status', 'status')
ORDER BY column_name;

-- Step 9: Check current bookings status distribution
SELECT 
    status,
    milestone_status,
    COUNT(*) as count
FROM bookings
GROUP BY status, milestone_status
ORDER BY status, milestone_status;
