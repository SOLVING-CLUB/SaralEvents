-- Cleanup script for booking_drafts table
-- This script removes unnecessary drafts that are:
-- 1. Completed (booking already created from draft)
-- 2. Expired (expires_at < NOW())
-- 3. Payment pending but older than 30 days (abandoned)

-- Enhanced cleanup function that removes:
-- - Completed drafts (older than 7 days)
-- - Expired drafts (regardless of status)
-- - Payment pending drafts older than 30 days (abandoned)
CREATE OR REPLACE FUNCTION cleanup_booking_drafts()
RETURNS TABLE(deleted_count INTEGER) AS $$
DECLARE
  completed_count INTEGER;
  expired_count INTEGER;
  abandoned_count INTEGER;
  total_count INTEGER;
BEGIN
  -- Delete completed drafts older than 7 days
  DELETE FROM booking_drafts
  WHERE status = 'completed'
    AND updated_at < NOW() - INTERVAL '7 days';
  GET DIAGNOSTICS completed_count = ROW_COUNT;

  -- Delete expired drafts (regardless of status)
  DELETE FROM booking_drafts
  WHERE expires_at < NOW();
  GET DIAGNOSTICS expired_count = ROW_COUNT;

  -- Delete payment_pending drafts older than 30 days (abandoned)
  DELETE FROM booking_drafts
  WHERE status = 'payment_pending'
    AND created_at < NOW() - INTERVAL '30 days';
  GET DIAGNOSTICS abandoned_count = ROW_COUNT;

  total_count := completed_count + expired_count + abandoned_count;
  
  RETURN QUERY SELECT total_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION cleanup_booking_drafts() TO authenticated;

-- Create a scheduled job (pg_cron) to run cleanup daily at 2 AM
-- Note: This requires pg_cron extension to be enabled in Supabase
-- You can also call this function manually or via Edge Function/webhook

-- Example: Schedule daily cleanup at 2 AM UTC
-- SELECT cron.schedule(
--   'cleanup-booking-drafts',
--   '0 2 * * *', -- Daily at 2 AM UTC
--   $$SELECT cleanup_booking_drafts();$$
-- );

-- Manual cleanup query (run this periodically or via cron)
-- SELECT cleanup_booking_drafts();

-- View current draft statistics
CREATE OR REPLACE FUNCTION get_draft_statistics()
RETURNS TABLE(
  status TEXT,
  count BIGINT,
  oldest_date TIMESTAMPTZ,
  newest_date TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    bd.status,
    COUNT(*)::BIGINT as count,
    MIN(bd.created_at) as oldest_date,
    MAX(bd.created_at) as newest_date
  FROM booking_drafts bd
  GROUP BY bd.status
  ORDER BY bd.status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_draft_statistics() TO authenticated;

-- View drafts that will be cleaned up (preview before deletion)
CREATE OR REPLACE FUNCTION preview_drafts_to_cleanup()
RETURNS TABLE(
  id UUID,
  user_id UUID,
  service_id UUID,
  status TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  cleanup_reason TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    bd.id,
    bd.user_id,
    bd.service_id,
    bd.status,
    bd.created_at,
    bd.updated_at,
    bd.expires_at,
    CASE
      WHEN bd.status = 'completed' AND bd.updated_at < NOW() - INTERVAL '7 days' 
        THEN 'Completed draft older than 7 days'
      WHEN bd.expires_at < NOW() 
        THEN 'Expired draft'
      WHEN bd.status = 'payment_pending' AND bd.created_at < NOW() - INTERVAL '30 days'
        THEN 'Abandoned payment_pending draft (older than 30 days)'
      ELSE 'Not eligible for cleanup'
    END as cleanup_reason
  FROM booking_drafts bd
  WHERE 
    (bd.status = 'completed' AND bd.updated_at < NOW() - INTERVAL '7 days')
    OR (bd.expires_at < NOW())
    OR (bd.status = 'payment_pending' AND bd.created_at < NOW() - INTERVAL '30 days')
  ORDER BY bd.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION preview_drafts_to_cleanup() TO authenticated;
