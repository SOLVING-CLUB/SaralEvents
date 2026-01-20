-- Purge Admin Portal Users (except Super Admin)
-- Keeps ONLY the super admin row in admin_users.
-- Safe preview included below.

BEGIN;

-- 1) Preview what will be deleted (run this first if you want to confirm):
-- SELECT id, email, role, is_active, created_at
-- FROM admin_users
-- WHERE lower(email) <> lower('admin@saralevents.com');

-- 2) Delete everyone except super admin
DELETE FROM admin_users
WHERE lower(email) <> lower('admin@saralevents.com');

-- 3) Ensure super admin stays active + correct role
UPDATE admin_users
SET role = 'super_admin',
    is_active = true,
    updated_at = NOW()
WHERE lower(email) = lower('admin@saralevents.com');

COMMIT;

