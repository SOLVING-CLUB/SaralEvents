-- Enable pg_net extension for HTTP requests in Supabase
-- Run this BEFORE running automated_notification_triggers.sql

-- Enable pg_net extension (Supabase's native extension for HTTP requests)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Verify extension is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_net';

-- If pg_net is not available, you can use http extension as fallback:
-- CREATE EXTENSION IF NOT EXISTS http;
