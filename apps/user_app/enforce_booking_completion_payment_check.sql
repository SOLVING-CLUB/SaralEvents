-- Enforce: booking cannot be marked as completed until COMPLETION (final 30%) milestone is paid
-- Run this in Supabase SQL Editor (user_app database)

BEGIN;

-- Helper: check if completion milestone is in a "paid enough" state
CREATE OR REPLACE FUNCTION public.is_completion_payment_done(p_booking_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.payment_milestones pm
    WHERE pm.booking_id = p_booking_id
      AND pm.milestone_type = 'completion'
      AND pm.status IN ('held_in_escrow', 'paid', 'released')
  );
$$;

-- Trigger function: prevent completing booking unless completion payment is done
CREATE OR REPLACE FUNCTION public.prevent_booking_completion_without_final_payment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Block transition to completed status
  IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') THEN
    IF NOT public.is_completion_payment_done(NEW.id) THEN
      RAISE EXCEPTION 'Cannot mark booking as completed until final payment (completion milestone) is paid.'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- Block transition to completed milestone_status (if used)
  IF NEW.milestone_status = 'completed' AND (OLD.milestone_status IS DISTINCT FROM 'completed') THEN
    IF NOT public.is_completion_payment_done(NEW.id) THEN
      RAISE EXCEPTION 'Cannot mark booking milestone_status as completed until final payment (completion milestone) is paid.'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Drop & recreate trigger (idempotent)
DROP TRIGGER IF EXISTS trg_prevent_booking_completion_without_final_payment ON public.bookings;
CREATE TRIGGER trg_prevent_booking_completion_without_final_payment
BEFORE UPDATE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.prevent_booking_completion_without_final_payment();

COMMIT;

