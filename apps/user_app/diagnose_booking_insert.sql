-- Diagnostic SQL to check booking insert permissions and RLS policies
-- Run this in Supabase SQL Editor

-- 1. Check RLS status
SELECT 
    tablename, 
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'bookings';

-- 2. Check INSERT policies on bookings table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'bookings'
AND cmd = 'INSERT';

-- 3. Check if authenticated users can insert
SELECT 
    grantee,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
AND table_name = 'bookings'
AND grantee = 'authenticated';

-- 4. Check recent booking attempts (if any exist)
SELECT 
    id,
    user_id,
    service_id,
    vendor_id,
    booking_date,
    status,
    milestone_status,
    created_at
FROM bookings
ORDER BY created_at DESC
LIMIT 5;

-- 5. Check if there are any constraints that might block inserts
SELECT
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.bookings'::regclass
AND contype IN ('c', 'f', 'u'); -- check, foreign key, unique

-- 6. Test insert permission (this will fail if RLS blocks it, but shows the error)
-- Uncomment and run with your actual user_id to test:
-- INSERT INTO bookings (user_id, service_id, vendor_id, booking_date, amount, status, milestone_status, vendor_accepted_at)
-- VALUES (
--     auth.uid(), -- Your user ID
--     '00000000-0000-0000-0000-000000000000'::uuid, -- Replace with actual service_id
--     '00000000-0000-0000-0000-000000000000'::uuid, -- Replace with actual vendor_id
--     CURRENT_DATE,
--     1000.00,
--     'confirmed',
--     'accepted',
--     NOW()
-- );

