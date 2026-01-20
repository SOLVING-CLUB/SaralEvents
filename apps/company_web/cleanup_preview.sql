-- PREVIEW SCRIPT - Run this FIRST to see what will be deleted
-- This is SAFE to run - it only shows what would be deleted, doesn't delete anything

-- Preview: Auth users that will be DELETED (not in admin_users, not super admin)
SELECT 
    'WILL BE DELETED' as action,
    id,
    email,
    created_at,
    last_sign_in_at,
    'auth.users' as source_table
FROM auth.users
WHERE 
    email != 'admin@saralevents.com'
    AND NOT EXISTS (
        SELECT 1 FROM admin_users 
        WHERE admin_users.user_id = auth.users.id
    )
    AND NOT EXISTS (
        SELECT 1 FROM admin_users 
        WHERE LOWER(admin_users.email) = LOWER(auth.users.email)
    )
ORDER BY created_at DESC;

-- Preview: Admin users that will be DELETED (orphaned entries)
SELECT 
    'WILL BE DELETED' as action,
    id,
    email,
    full_name,
    role,
    user_id,
    created_at,
    'admin_users' as source_table
FROM admin_users
WHERE 
    LOWER(email) != LOWER('admin@saralevents.com')
    AND (
        user_id IS NULL 
        OR NOT EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = admin_users.user_id
        )
    )
ORDER BY created_at DESC;

-- Preview: What will be KEPT
SELECT 
    'WILL BE KEPT' as action,
    au.id as admin_user_id,
    au.email,
    au.full_name,
    au.role,
    au.user_id,
    au.is_active,
    au.created_at,
    'Both tables' as source_table
FROM admin_users au
LEFT JOIN auth.users au_auth ON au.user_id = au_auth.id OR LOWER(au.email) = LOWER(au_auth.email)
WHERE 
    LOWER(au.email) = LOWER('admin@saralevents.com')
    OR au_auth.id IS NOT NULL
ORDER BY au.created_at DESC;
