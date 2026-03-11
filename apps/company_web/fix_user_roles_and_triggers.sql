-- Fix User Roles and Automatic Triggers
-- This script ensures that roles are automatically assigned and that multiple roles are handled correctly.

-- 1. Create the user_roles table if it doesn't exist (ensure UNIQUE constraint)
CREATE TABLE IF NOT EXISTS user_roles (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'vendor', 'company')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, role)
);

-- 2. Function to automatically assign 'vendor' role
CREATE OR REPLACE FUNCTION handle_vendor_role_assignment()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_roles (user_id, role)
    VALUES (NEW.user_id, 'vendor')
    ON CONFLICT (user_id, role) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Trigger for vendor_profiles
DROP TRIGGER IF EXISTS on_vendor_profile_created ON vendor_profiles;
CREATE TRIGGER on_vendor_profile_created
    AFTER INSERT ON vendor_profiles
    FOR EACH ROW
    EXECUTE FUNCTION handle_vendor_role_assignment();

-- 4. Function to automatically assign 'user' role
CREATE OR REPLACE FUNCTION handle_user_role_assignment()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_roles (user_id, role)
    VALUES (NEW.user_id, 'user')
    ON CONFLICT (user_id, role) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Trigger for user_profiles
DROP TRIGGER IF EXISTS on_user_profile_created ON user_profiles;
CREATE TRIGGER on_user_profile_created
    AFTER INSERT ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION handle_user_role_assignment();

-- 6. Update get_user_role to handle multiple roles (optional, but good for backward compatibility)
-- Returning a comma-separated string of roles
CREATE OR REPLACE FUNCTION get_user_roles_string(user_uuid UUID DEFAULT auth.uid())
RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT string_agg(role, ', ')
        FROM user_roles
        WHERE user_id = user_uuid
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Backfill existing vendors and users who might be missing roles
INSERT INTO user_roles (user_id, role)
SELECT user_id, 'vendor' FROM vendor_profiles
ON CONFLICT (user_id, role) DO NOTHING;

INSERT INTO user_roles (user_id, role)
SELECT user_id, 'user' FROM user_profiles
ON CONFLICT (user_id, role) DO NOTHING;

-- 8. Fix RLS on vendor_profiles to allow insertion by any authenticated user
-- This solves the chicken-and-egg problem where you needed the vendor role to create the profile.
DROP POLICY IF EXISTS "Vendors can insert own profile" ON vendor_profiles;
CREATE POLICY "Authenticated users can create vendor profile" ON vendor_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 9. Fix RLS on user_roles so users can see their own roles (already exists, but ensuring it)
DROP POLICY IF EXISTS "Users can view own roles" ON user_roles;
CREATE POLICY "Users can view own roles" ON user_roles
    FOR SELECT USING (auth.uid() = user_id);

-- 10. Admin override: Allow admins to see ALL roles
-- Note: This assumes there is an admin_users table or similar check.
-- If you have a specific admin check, add it here.
CREATE POLICY "Admins can view all roles" ON user_roles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM admin_users WHERE user_id = auth.uid()
        )
    );
