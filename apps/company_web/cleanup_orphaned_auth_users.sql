-- Cleanup Orphaned Auth Users and Admin Portal Users
-- This script removes all auth.users accounts that are NOT in admin_users table
-- Keeps ONLY the super admin account (admin@saralevents.com)
--
-- WARNING: This will permanently delete user accounts from auth.users
-- Make sure you have backups before running this!

BEGIN;

-- Temporarily disable problematic triggers that might interfere with cleanup.
-- Your error indicates a trigger FUNCTION named trigger_update_event_statistics() is firing.
-- The trigger name may differ, so we disable any trigger that EXECUTES the function
-- public.trigger_update_event_statistics() across the public schema.
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT n.nspname AS schema_name, c.relname AS table_name, t.tgname AS trigger_name
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_proc p ON p.oid = t.tgfoid
    JOIN pg_namespace pn ON pn.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND pn.nspname = 'public'
      AND p.proname = 'trigger_update_event_statistics'
      AND NOT t.tgisinternal
  LOOP
    EXECUTE format('ALTER TABLE %I.%I DISABLE TRIGGER %I', r.schema_name, r.table_name, r.trigger_name);
  END LOOP;
END
$$;

-- Clean up any orphaned event_statistics rows with null event_id
DELETE FROM event_statistics WHERE event_id IS NULL;

-- Step 1: Preview what will be deleted from auth.users
-- Uncomment to see what will be deleted:
/*
SELECT 
    id,
    email,
    created_at,
    last_sign_in_at,
    CASE 
        WHEN email = 'admin@saralevents.com' THEN 'KEEP (Super Admin)'
        WHEN EXISTS (
            SELECT 1 FROM admin_users 
            WHERE admin_users.user_id = auth.users.id 
            OR admin_users.email = auth.users.email
        ) THEN 'KEEP (In admin_users)'
        ELSE 'DELETE'
    END as action
FROM auth.users
ORDER BY created_at DESC;
*/

-- Step 2: Identify auth.users entries that are NOT in admin_users table
-- Note: CTEs (WITH ...) only live for ONE statement, so we persist the list
-- into a temporary table so we can use it across multiple deletes.
-- This keeps:
-- 1. Super admin (admin@saralevents.com)
-- 2. Any user whose user_id or email exists in admin_users table

DROP TABLE IF EXISTS users_to_delete;
CREATE TEMP TABLE users_to_delete AS
SELECT id
FROM auth.users
WHERE 
    -- Keep super admin
    email != 'admin@saralevents.com'
    -- Delete if NOT in admin_users table (by user_id or email)
    AND NOT EXISTS (
        SELECT 1 FROM admin_users 
        WHERE admin_users.user_id = auth.users.id
    )
    AND NOT EXISTS (
        SELECT 1 FROM admin_users 
        WHERE LOWER(admin_users.email) = LOWER(auth.users.email)
    );

-- First, delete dependent records in faqs (and other tables if needed)
DELETE FROM faqs
WHERE created_by IN (SELECT id FROM users_to_delete);

-- Delete dependent notification campaigns created by these users
DELETE FROM notification_campaigns
WHERE created_by IN (SELECT id FROM users_to_delete);

-- Delete booking status updates attributed to these users
DELETE FROM booking_status_updates
WHERE updated_by IN (SELECT id FROM users_to_delete);

-- Then delete from auth.users
DELETE FROM auth.users
WHERE id IN (SELECT id FROM users_to_delete);

-- Step 3: Clean up orphaned admin_users entries (entries without matching auth.users)
-- These are entries that were created but the user never signed up
DELETE FROM admin_users
WHERE 
    -- Keep super admin
    LOWER(email) != LOWER('admin@saralevents.com')
    -- Delete if user_id is NULL (user never signed up) OR user_id doesn't exist in auth.users
    AND (
        user_id IS NULL 
        OR NOT EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = admin_users.user_id
        )
    );

-- Step 4: Ensure super admin exists and is properly configured
INSERT INTO admin_users (email, full_name, role, is_active, user_id)
SELECT 
    'admin@saralevents.com',
    'Super Admin',
    'super_admin',
    true,
    (SELECT id FROM auth.users WHERE email = 'admin@saralevents.com' LIMIT 1)
ON CONFLICT (email) DO UPDATE
SET 
    role = 'super_admin',
    is_active = true,
    updated_at = NOW(),
    user_id = COALESCE(
        admin_users.user_id,
        (SELECT id FROM auth.users WHERE email = 'admin@saralevents.com' LIMIT 1)
    );

-- Step 5: Verify cleanup results
-- Uncomment to see final state:
/*
SELECT 
    'auth.users' as table_name,
    COUNT(*) as count,
    COUNT(CASE WHEN email = 'admin@saralevents.com' THEN 1 END) as super_admin_count
FROM auth.users
UNION ALL
SELECT 
    'admin_users' as table_name,
    COUNT(*) as count,
    COUNT(CASE WHEN LOWER(email) = LOWER('admin@saralevents.com') THEN 1 END) as super_admin_count
FROM admin_users;
*/

-- Re-enable any triggers we disabled above
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT n.nspname AS schema_name, c.relname AS table_name, t.tgname AS trigger_name
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_proc p ON p.oid = t.tgfoid
    JOIN pg_namespace pn ON pn.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND pn.nspname = 'public'
      AND p.proname = 'trigger_update_event_statistics'
      AND NOT t.tgisinternal
  LOOP
    EXECUTE format('ALTER TABLE %I.%I ENABLE TRIGGER %I', r.schema_name, r.table_name, r.trigger_name);
  END LOOP;
END
$$;

COMMIT;

-- Final verification query (run separately to check results):
-- SELECT 'auth.users count:' as info, COUNT(*) as count FROM auth.users
-- UNION ALL
-- SELECT 'admin_users count:' as info, COUNT(*) as count FROM admin_users
-- UNION ALL
-- SELECT 'Super admin in auth.users:' as info, COUNT(*) as count FROM auth.users WHERE email = 'admin@saralevents.com'
-- UNION ALL
-- SELECT 'Super admin in admin_users:' as info, COUNT(*) as count FROM admin_users WHERE LOWER(email) = LOWER('admin@saralevents.com');
