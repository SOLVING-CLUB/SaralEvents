-- Admin Policies for Support Tickets and FAQs
-- These policies allow authenticated users (admin portal) to manage support tickets and FAQs
-- Note: If you have an admin_users table, you can update these policies to check roles

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Admins can view all support tickets" ON support_tickets;
DROP POLICY IF EXISTS "Admins can update all support tickets" ON support_tickets;
DROP POLICY IF EXISTS "Admins can delete support tickets" ON support_tickets;
DROP POLICY IF EXISTS "Admins can view all FAQs" ON faqs;
DROP POLICY IF EXISTS "Admins can create FAQs" ON faqs;
DROP POLICY IF EXISTS "Admins can update FAQs" ON faqs;
DROP POLICY IF EXISTS "Admins can delete FAQs" ON faqs;

-- Support Tickets Admin Policies
-- Allow authenticated users to view all tickets (admin portal access)
CREATE POLICY "Admins can view all support tickets" ON support_tickets
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Allow authenticated users to update all tickets
CREATE POLICY "Admins can update all support tickets" ON support_tickets
  FOR UPDATE
  USING (auth.uid() IS NOT NULL);

-- Allow authenticated users to delete tickets (optional, based on your needs)
-- Uncomment if you want admins to be able to delete tickets
-- CREATE POLICY "Admins can delete support tickets" ON support_tickets
--   FOR DELETE
--   USING (auth.uid() IS NOT NULL);

-- FAQs Admin Policies
-- Allow authenticated users to view all FAQs (including inactive ones)
CREATE POLICY "Admins can view all FAQs" ON faqs
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL  -- Admins can see all FAQs
    OR is_active = true  -- Regular users can see active FAQs
  );

-- Allow authenticated users to insert FAQs
CREATE POLICY "Admins can create FAQs" ON faqs
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Allow authenticated users to update FAQs
CREATE POLICY "Admins can update FAQs" ON faqs
  FOR UPDATE
  USING (auth.uid() IS NOT NULL);

-- Allow authenticated users to delete FAQs
CREATE POLICY "Admins can delete FAQs" ON faqs
  FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- Grant UPDATE permission on support_tickets to authenticated users (for admin portal)
GRANT UPDATE ON support_tickets TO authenticated;

-- Grant all permissions on faqs to authenticated users (for admin portal)
GRANT SELECT, INSERT, UPDATE, DELETE ON faqs TO authenticated;

-- Note: If you want to add role-based access later, create an admin_users table and update policies like this:
-- CREATE POLICY "Admins can view all support tickets" ON support_tickets
--   FOR SELECT
--   USING (
--     EXISTS (
--       SELECT 1 FROM admin_users
--       WHERE admin_users.user_id = auth.uid()
--       AND admin_users.role IN ('super_admin', 'admin', 'support')
--       AND admin_users.is_active = true
--     )
--   );
--
-- To create the admin_users table, use:
-- CREATE TABLE IF NOT EXISTS admin_users (
--   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--   user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
--   email TEXT NOT NULL,
--   full_name TEXT,
--   role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('super_admin', 'admin', 'support', 'finance', 'marketing', 'viewer')),
--   is_active BOOLEAN DEFAULT true,
--   created_at TIMESTAMPTZ DEFAULT NOW(),
--   last_login TIMESTAMPTZ
-- );
