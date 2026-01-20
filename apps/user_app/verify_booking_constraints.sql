-- Verify all constraints on bookings table
-- Run this to check what constraints are actually active

-- 1. Check milestone_status constraint
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'bookings'::regclass
AND conname LIKE '%milestone%'
ORDER BY conname;

-- 2. Check status constraint
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'bookings'::regclass
AND conname LIKE '%status%'
ORDER BY conname;

-- 3. List ALL constraints on bookings table
SELECT 
    conname AS constraint_name,
    contype AS constraint_type,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'bookings'::regclass
ORDER BY conname;

-- 4. Check for triggers that might modify milestone_status
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'bookings'
ORDER BY trigger_name;

-- 5. Test if 'created' value is allowed (should return no rows if constraint allows it)
SELECT 
    'created'::text AS test_value,
    CASE 
        WHEN 'created'::text = ANY(ARRAY['created'::text, 'accepted'::text, 'vendor_traveling'::text, 'vendor_arrived'::text, 'arrival_confirmed'::text, 'setup_completed'::text, 'setup_confirmed'::text, 'completed'::text, 'cancelled'::text])
        THEN 'ALLOWED'
        ELSE 'NOT ALLOWED'
    END AS constraint_check;
