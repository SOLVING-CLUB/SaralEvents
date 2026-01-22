-- Enforce Payment Check Before Setup Completion
-- This trigger ensures vendors cannot mark setup as completed until arrival payment is confirmed

-- Function to check if arrival payment is completed before allowing setup_completed status
CREATE OR REPLACE FUNCTION check_arrival_payment_before_setup()
RETURNS TRIGGER AS $$
DECLARE
  arrival_milestone_status TEXT;
BEGIN
  -- Only check when milestone_status is being changed to 'setup_completed'
  IF NEW.milestone_status = 'setup_completed' AND 
     (OLD.milestone_status IS NULL OR OLD.milestone_status != 'setup_completed') THEN
    
    -- Check if milestone_status is 'arrival_confirmed' (user confirmed arrival)
    IF NEW.milestone_status = 'setup_completed' AND 
       (OLD.milestone_status != 'arrival_confirmed') THEN
      RAISE EXCEPTION 'Cannot mark setup as completed: Booking must be in "arrival_confirmed" status first';
    END IF;
    
    -- Check if arrival payment milestone is paid/held_in_escrow
    SELECT status INTO arrival_milestone_status
    FROM payment_milestones
    WHERE booking_id = NEW.id
      AND milestone_type = 'arrival';
    
    -- If milestone doesn't exist, that's also an error
    IF arrival_milestone_status IS NULL THEN
      RAISE EXCEPTION 'Cannot mark setup as completed: Arrival payment milestone not found';
    END IF;
    
    -- Check if payment is completed (held_in_escrow, paid, or released)
    IF arrival_milestone_status NOT IN ('held_in_escrow', 'paid', 'released') THEN
      RAISE EXCEPTION 'Cannot mark setup as completed: Arrival payment (50%%) must be completed first. Current status: %', 
        arrival_milestone_status;
    END IF;
    
    RAISE NOTICE '✅ Setup completion allowed: Arrival payment confirmed (status: %)', arrival_milestone_status;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to enforce payment check
DROP TRIGGER IF EXISTS trigger_check_arrival_payment_before_setup ON bookings;
CREATE TRIGGER trigger_check_arrival_payment_before_setup
  BEFORE UPDATE OF milestone_status ON bookings
  FOR EACH ROW
  WHEN (NEW.milestone_status = 'setup_completed')
  EXECUTE FUNCTION check_arrival_payment_before_setup();

-- Add comment explaining the trigger
COMMENT ON FUNCTION check_arrival_payment_before_setup IS 
  'Enforces that vendors cannot mark setup as completed until arrival payment (50%) is confirmed. Checks payment_milestones table for arrival milestone status.';
