-- Fix milestone_status constraint to allow 'created' status for vendor acceptance flow
-- This allows bookings to be created with milestone_status='created' waiting for vendor acceptance

-- Step 1: Drop the existing constraint
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_milestone_status_check;

-- Step 2: Add the constraint back with 'created' included
ALTER TABLE bookings ADD CONSTRAINT bookings_milestone_status_check 
  CHECK (milestone_status IS NULL OR milestone_status IN (
    'created',           -- Booking created, waiting for vendor acceptance
    'accepted',          -- Vendor accepted booking
    'vendor_traveling',  -- Vendor is traveling to location
    'vendor_arrived',    -- Vendor marked as arrived at location
    'arrival_confirmed', -- Customer confirmed vendor arrival
    'setup_completed',   -- Vendor marked setup as completed
    'setup_confirmed',   -- Customer confirmed setup completion
    'completed',         -- All milestones completed
    'cancelled'          -- Booking cancelled
  ));

-- Step 3: Verify the constraint
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'bookings'::regclass
AND conname = 'bookings_milestone_status_check';

-- Step 4: Check current bookings with invalid milestone_status
SELECT 
    id,
    status,
    milestone_status,
    created_at
FROM bookings
WHERE milestone_status IS NOT NULL
AND milestone_status NOT IN ('created', 'accepted', 'vendor_traveling', 'vendor_arrived', 'arrival_confirmed', 'setup_completed', 'setup_confirmed', 'completed', 'cancelled')
LIMIT 10;
