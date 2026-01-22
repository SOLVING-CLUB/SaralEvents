-- Enforce Slot Locking: Prevent Double-Booking
-- This ensures that when a service is booked, the date/time slot is locked
-- and cannot be booked by another user unless the booking is cancelled

-- 1. Create a function to check if a slot is available before booking
CREATE OR REPLACE FUNCTION check_slot_availability(
  p_service_id UUID,
  p_booking_date DATE,
  p_booking_time TIME
) RETURNS BOOLEAN AS $$
DECLARE
  conflicting_booking_count INTEGER;
BEGIN
  -- Check for active bookings (pending or confirmed) on the same service, date, and time
  -- Exclude cancelled and completed bookings
  SELECT COUNT(*) INTO conflicting_booking_count
  FROM bookings
  WHERE service_id = p_service_id
    AND booking_date = p_booking_date
    AND booking_time = p_booking_time
    AND status IN ('pending', 'confirmed')
    AND milestone_status NOT IN ('cancelled');
  
  -- Return true if no conflicts (slot is available)
  RETURN conflicting_booking_count = 0;
END;
$$ LANGUAGE plpgsql;

-- 2. Create a trigger function to prevent double-booking
CREATE OR REPLACE FUNCTION prevent_double_booking()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if slot is available before allowing insert
  IF NOT check_slot_availability(
    NEW.service_id,
    NEW.booking_date,
    NEW.booking_time
  ) THEN
    RAISE EXCEPTION 'Slot already booked: Service % on date % at time % is already booked by another user',
      NEW.service_id, NEW.booking_date, NEW.booking_time;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create trigger to enforce slot locking on INSERT
DROP TRIGGER IF EXISTS trigger_prevent_double_booking ON bookings;
CREATE TRIGGER trigger_prevent_double_booking
  BEFORE INSERT ON bookings
  FOR EACH ROW
  WHEN (NEW.booking_time IS NOT NULL)
  EXECUTE FUNCTION prevent_double_booking();

-- 4. Create trigger to prevent updating a booking to conflict with another active booking
CREATE OR REPLACE FUNCTION prevent_double_booking_on_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Only check if booking_time or booking_date is being changed
  IF (OLD.booking_time IS DISTINCT FROM NEW.booking_time) OR 
     (OLD.booking_date IS DISTINCT FROM NEW.booking_date) THEN
    
    -- If status is being changed to cancelled, allow it (slot should be freed)
    IF NEW.status = 'cancelled' OR NEW.milestone_status = 'cancelled' THEN
      RETURN NEW;
    END IF;
    
    -- Check if the new slot conflicts with another active booking
    IF NOT check_slot_availability(
      NEW.service_id,
      NEW.booking_date,
      NEW.booking_time
    ) THEN
      -- Allow if it's the same booking (updating other fields)
      IF OLD.id = NEW.id THEN
        -- Check if there's another booking with same slot (excluding this one)
        IF EXISTS (
          SELECT 1 FROM bookings
          WHERE service_id = NEW.service_id
            AND booking_date = NEW.booking_date
            AND booking_time = NEW.booking_time
            AND status IN ('pending', 'confirmed')
            AND milestone_status NOT IN ('cancelled')
            AND id != NEW.id
        ) THEN
          RAISE EXCEPTION 'Slot already booked: Service % on date % at time % is already booked by another user',
            NEW.service_id, NEW.booking_date, NEW.booking_time;
        END IF;
      ELSE
        RAISE EXCEPTION 'Slot already booked: Service % on date % at time % is already booked by another user',
          NEW.service_id, NEW.booking_date, NEW.booking_time;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger to enforce slot locking on UPDATE
DROP TRIGGER IF EXISTS trigger_prevent_double_booking_update ON bookings;
CREATE TRIGGER trigger_prevent_double_booking_update
  BEFORE UPDATE ON bookings
  FOR EACH ROW
  WHEN (NEW.booking_time IS NOT NULL)
  EXECUTE FUNCTION prevent_double_booking_on_update();

-- 6. Add index for faster availability checks
CREATE INDEX IF NOT EXISTS idx_bookings_slot_availability 
  ON bookings(service_id, booking_date, booking_time, status)
  WHERE status IN ('pending', 'confirmed') AND milestone_status NOT IN ('cancelled');

-- 7. Add comment explaining the locking mechanism
COMMENT ON FUNCTION check_slot_availability IS 
  'Checks if a service slot (service_id + date + time) is available by counting active bookings. Returns true if available (no conflicts).';

COMMENT ON FUNCTION prevent_double_booking IS 
  'Trigger function that prevents inserting a booking if the slot is already booked by another active booking.';

COMMENT ON FUNCTION prevent_double_booking_on_update IS 
  'Trigger function that prevents updating a booking to a slot that is already booked by another active booking. Allows cancellation to free slots.';
