-- Refund admin policies for company web app
-- Run this in Supabase SQL editor to allow admin users to manage all refunds.

-- Ensure RLS is enabled on refunds table
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;

-- Allow customers to view their own refunds (if not already set by other migrations)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = current_schema()
      AND tablename = 'refunds'
      AND policyname = 'Users can view their refunds'
  ) THEN
    EXECUTE '
      CREATE POLICY "Users can view their refunds" ON refunds
        FOR SELECT USING (
          EXISTS (
            SELECT 1 FROM bookings b
            WHERE b.id = refunds.booking_id
              AND b.user_id = auth.uid()
          )
        )
    ';
  END IF;
END;
$$;

-- Admins (entries in admin_users table) can view ALL refunds
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = current_schema()
      AND tablename = 'refunds'
      AND policyname = 'Admins can view all refunds'
  ) THEN
    EXECUTE '
      CREATE POLICY "Admins can view all refunds" ON refunds
        FOR SELECT USING (
          EXISTS (
            SELECT 1
            FROM admin_users au
            WHERE au.user_id = auth.uid()
              AND au.is_active = true
          )
        )
    ';
  END IF;
END;
$$;

-- Admins can update refunds (change status, amounts, etc.)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = current_schema()
      AND tablename = 'refunds'
      AND policyname = 'Admins can update refunds'
  ) THEN
    EXECUTE '
      CREATE POLICY "Admins can update refunds" ON refunds
        FOR UPDATE USING (
          EXISTS (
            SELECT 1
            FROM admin_users au
            WHERE au.user_id = auth.uid()
              AND au.is_active = true
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM admin_users au
            WHERE au.user_id = auth.uid()
              AND au.is_active = true
          )
        )
    ';
  END IF;
END;
$$;

