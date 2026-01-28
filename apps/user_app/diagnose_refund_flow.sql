-- Diagnose why cancelled bookings are not creating refunds / not visible in company app
-- Run this in Supabase SQL editor.

-- 1) Recent cancelled bookings
SELECT 
  b.id AS booking_id,
  b.user_id,
  b.vendor_id,
  b.status,
  b.amount,
  b.booking_date,
  b.created_at,
  b.updated_at
FROM bookings b
WHERE b.status = 'cancelled'
ORDER BY b.updated_at DESC NULLS LAST, b.created_at DESC
LIMIT 20;

-- 2) Recent refunds
SELECT
  r.id,
  r.booking_id,
  r.cancelled_by,
  r.refund_amount,
  r.non_refundable_amount,
  r.refund_percentage,
  r.status,
  r.created_at,
  r.processed_at,
  r.processed_by
FROM refunds r
ORDER BY r.created_at DESC
LIMIT 20;

-- 3) Cancelled bookings that DO NOT have a refund row
SELECT
  b.id AS booking_id,
  b.user_id,
  b.vendor_id,
  b.status,
  b.amount,
  b.booking_date,
  b.created_at,
  b.updated_at
FROM bookings b
LEFT JOIN refunds r ON r.booking_id = b.id
WHERE b.status = 'cancelled'
  AND r.id IS NULL
ORDER BY b.updated_at DESC NULLS LAST, b.created_at DESC
LIMIT 20;

-- 4) Check RLS policies on refunds and refund_milestones
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename IN ('refunds', 'refund_milestones')
ORDER BY tablename, policyname;

-- 5) Check basic grants on refunds tables (authenticated role)
SELECT 
  grantee,
  table_name,
  privilege_type
FROM information_schema.table_privileges
WHERE table_name IN ('refunds', 'refund_milestones')
ORDER BY grantee, table_name, privilege_type;

