-- ============================================================================
-- SETUP CART ABANDONMENT SCHEDULED FUNCTION
-- This script sets up the scheduled cart abandonment check
-- ============================================================================
-- The Edge Function should be deployed first:
-- cd apps/user_app/supabase/functions
-- supabase functions deploy cart-abandonment-check

-- Step 1: Ensure pg_net extension is enabled (required for scheduled HTTP calls)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Step 2: Get your Supabase project URL (replace with your actual URL)
-- You can find this in Supabase Dashboard > Settings > API > Project URL
DO $$
DECLARE
  v_supabase_url TEXT := 'https://hucsihwqsuvqvbnyapdn.supabase.co'; -- REPLACE WITH YOUR URL
  v_service_role_key TEXT := current_setting('app.supabase_service_role_key', true);
BEGIN
  -- Check if service role key is set
  IF v_service_role_key IS NULL OR v_service_role_key = '' THEN
    RAISE NOTICE '⚠️ WARNING: app.supabase_service_role_key is not set.';
    RAISE NOTICE 'Please set it with: ALTER DATABASE postgres SET app.supabase_service_role_key = ''your-service-role-key'';';
    RAISE NOTICE 'You can find your service role key in Supabase Dashboard > Settings > API > Secret keys';
  END IF;
END $$;

-- Step 3: Schedule the cart abandonment check (runs every hour)
-- IMPORTANT: Supabase recommends using the Dashboard for scheduling Edge Functions
-- pg_cron may not be available or may have limitations with Edge Functions

-- Option A: Check if pg_cron is available and provide instructions
DO $$
BEGIN
  -- Check if pg_cron extension exists
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE '✅ pg_cron extension is available';
    RAISE NOTICE '⚠️ However, Supabase recommends scheduling Edge Functions via Dashboard';
    RAISE NOTICE '';
    RAISE NOTICE 'RECOMMENDED: Use Supabase Dashboard to schedule:';
    RAISE NOTICE '1. Go to Supabase Dashboard > Database > Cron Jobs (or Edge Functions > Cron)';
    RAISE NOTICE '2. Create new cron job:';
    RAISE NOTICE '   - Name: cart-abandonment-check';
    RAISE NOTICE '   - Schedule: 0 * * * * (every hour)';
    RAISE NOTICE '   - Function: cart-abandonment-check';
    RAISE NOTICE '   - Payload: {}';
    RAISE NOTICE '';
    RAISE NOTICE 'If you want to use pg_cron, you can create a helper function first:';
  ELSE
    RAISE NOTICE '⚠️ pg_cron extension is not available';
    RAISE NOTICE '';
    RAISE NOTICE 'RECOMMENDED: Schedule via Supabase Dashboard:';
    RAISE NOTICE '1. Go to Supabase Dashboard > Database > Cron Jobs (or Edge Functions > Cron)';
    RAISE NOTICE '2. Create new cron job:';
    RAISE NOTICE '   - Name: cart-abandonment-check';
    RAISE NOTICE '   - Schedule: 0 * * * * (every hour)';
    RAISE NOTICE '   - Function: cart-abandonment-check';
    RAISE NOTICE '   - Payload: {}';
  END IF;
END $$;

-- Step 4: Create helper function for pg_cron (optional, if you want to use pg_cron)
-- This creates a function that can be called by pg_cron to invoke the Edge Function
CREATE OR REPLACE FUNCTION invoke_cart_abandonment_check()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_role_key TEXT;
  v_request_id BIGINT;
BEGIN
  -- Get configuration
  v_supabase_url := current_setting('app.supabase_url', true);
  v_service_role_key := current_setting('app.supabase_service_role_key', true);
  
  -- Validate configuration
  IF v_supabase_url IS NULL OR v_supabase_url = '' THEN
    RAISE WARNING 'app.supabase_url is not set. Cannot invoke cart abandonment check.';
    RETURN;
  END IF;
  
  IF v_service_role_key IS NULL OR v_service_role_key = '' THEN
    RAISE WARNING 'app.supabase_service_role_key is not set. Cannot invoke cart abandonment check.';
    RETURN;
  END IF;
  
  -- Use pg_net to call the Edge Function
  BEGIN
    v_request_id := net.http_post(
      url := v_supabase_url || '/functions/v1/cart-abandonment-check',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_service_role_key,
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    );
    
    RAISE NOTICE 'Cart abandonment check invoked. Request ID: %', v_request_id;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Failed to invoke cart abandonment check: %', SQLERRM;
  END;
END;
$$;

-- Step 5: Schedule using pg_cron (optional - only if you want to use pg_cron instead of Dashboard)
-- Uncomment the following if you want to use pg_cron:
/*
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Unschedule existing job if it exists
    PERFORM cron.unschedule('cart-abandonment-check');
    
    -- Schedule new job (runs every hour at minute 0)
    PERFORM cron.schedule(
      'cart-abandonment-check',
      '0 * * * *', -- Every hour at minute 0
      'SELECT invoke_cart_abandonment_check();'
    );
    
    RAISE NOTICE '✅ Cart abandonment check scheduled using pg_cron';
  END IF;
END $$;
*/

-- Step 6: Verify the schedule (if pg_cron was used)
-- Uncomment to check:
/*
SELECT 
  jobid,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active
FROM cron.job
WHERE jobname = 'cart-abandonment-check';
*/

-- ============================================================================
-- RECOMMENDED: MANUAL SCHEDULING VIA SUPABASE DASHBOARD
-- ============================================================================
-- Supabase recommends scheduling Edge Functions via the Dashboard
-- This is the most reliable method and works on all Supabase plans
--
-- Steps:
-- 1. Deploy the Edge Function first:
--    cd apps/user_app/supabase/functions
--    supabase functions deploy cart-abandonment-check
--
-- 2. Go to Supabase Dashboard
-- 3. Navigate to one of these (depending on your Supabase version):
--    - Database > Cron Jobs
--    - Edge Functions > Cron
--    - Database > Extensions > pg_cron (if available)
--
-- 4. Click "Create Cron Job" or "Schedule Function"
-- 5. Fill in:
--    - Name: cart-abandonment-check
--    - Schedule: 0 * * * * (runs every hour at minute 0)
--    - Function: cart-abandonment-check
--    - Payload: {}
--    - Enabled: ✅ Yes
-- 6. Save
--
-- This is the RECOMMENDED method and will work reliably!

-- ============================================================================
-- TEST THE FUNCTION MANUALLY
-- ============================================================================
-- You can test the function manually by calling the helper function:
--
-- SELECT invoke_cart_abandonment_check();
--
-- Or test directly via pg_net (if available):
--
-- SELECT net.http_post(
--   url := current_setting('app.supabase_url', true) || '/functions/v1/cart-abandonment-check',
--   headers := jsonb_build_object(
--     'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true),
--     'Content-Type', 'application/json'
--   ),
--   body := '{}'::jsonb
-- );
--
-- Or test via Supabase Dashboard:
-- 1. Go to Edge Functions > cart-abandonment-check
-- 2. Click "Invoke" or "Test"
-- 3. Check the logs for results
