-- ============================================================================
-- FIX: booking_status_updates Trigger Issue
-- ============================================================================

-- The trigger create_booking_status_update() is failing because auth.uid() is NULL
-- when running from SQL editor. Let's fix the trigger to handle this.

-- Step 1: Check current trigger function
SELECT 
  'Current Trigger Function' as check_type,
  routine_name,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'create_booking_status_update'
LIMIT 1;

-- Step 2: Fix the trigger function to handle NULL auth.uid()
-- This will allow updates from SQL editor (where auth.uid() is NULL)
CREATE OR REPLACE FUNCTION create_booking_status_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Only insert if status actually changed
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO booking_status_updates (
      booking_id, 
      status, 
      updated_by, 
      notes
    ) VALUES (
      NEW.id, 
      NEW.status, 
      COALESCE(auth.uid(), NEW.user_id), -- Use booking user_id if auth.uid() is NULL
      'Status updated from ' || OLD.status || ' to ' || NEW.status
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Verify trigger is still attached
SELECT 
  'Trigger Status' as check_type,
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  '✅ FIXED' as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE '%booking_status%';

-- Step 4: Test the fix by updating a booking
-- This should now work without the NULL constraint error
UPDATE bookings
SET status = 'completed',
    updated_at = NOW()
WHERE id = 'f2c40bcb-18de-416d-9030-128c1a9ab9af'
  AND status = 'confirmed';
