-- Set missing configuration parameters
-- Replace with your actual Supabase URL (from your project settings)
ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT_ID.supabase.co';

-- Replace with your SERVICE_ROLE_KEY (from Project Settings -> API)
-- WARNING: Do not expose this key in public repos/clients. This is safe to run in SQL Editor.
ALTER DATABASE postgres SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';

-- Verify settings
SELECT current_setting('app.supabase_url', true);
