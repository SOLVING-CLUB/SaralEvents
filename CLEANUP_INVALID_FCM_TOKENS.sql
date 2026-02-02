-- ============================================================================
-- CLEANUP INVALID FCM TOKENS
-- Run this to clean up old or invalid tokens
-- ============================================================================

-- Option 1: Mark very old tokens as inactive (older than 30 days)
-- These are likely expired or from uninstalled apps
UPDATE fcm_tokens
SET is_active = false
WHERE updated_at < NOW() - INTERVAL '30 days'
  AND is_active = true;

-- Check how many were deactivated
SELECT 
  'Old Tokens Deactivated' as action,
  COUNT(*) as count
FROM fcm_tokens
WHERE updated_at < NOW() - INTERVAL '30 days'
  AND is_active = false;

-- Option 2: Keep only the most recent token per user per app_type
-- This removes duplicate tokens (keeps the newest one)
WITH ranked_tokens AS (
  SELECT 
    id,
    user_id,
    app_type,
    updated_at,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, app_type 
      ORDER BY updated_at DESC
    ) as rn
  FROM fcm_tokens
  WHERE is_active = true
)
UPDATE fcm_tokens
SET is_active = false
WHERE id IN (
  SELECT id FROM ranked_tokens WHERE rn > 1
);

-- Check duplicates removed
SELECT 
  'Duplicate Tokens Removed' as action,
  COUNT(*) as count
FROM fcm_tokens
WHERE is_active = false
  AND updated_at >= NOW() - INTERVAL '1 hour';

-- Option 3: Summary of token status
SELECT 
  'Token Status Summary' as check_type,
  app_type,
  COUNT(*) as total_tokens,
  COUNT(CASE WHEN is_active = true THEN 1 END) as active_tokens,
  COUNT(CASE WHEN is_active = false THEN 1 END) as inactive_tokens,
  COUNT(CASE WHEN updated_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_tokens,
  COUNT(CASE WHEN updated_at < NOW() - INTERVAL '30 days' THEN 1 END) as old_tokens
FROM fcm_tokens
GROUP BY app_type
ORDER BY app_type;

-- Option 4: Find users with multiple active tokens (potential duplicates)
SELECT 
  'Users with Multiple Active Tokens' as check_type,
  user_id,
  app_type,
  COUNT(*) as token_count,
  MAX(updated_at) as most_recent,
  MIN(updated_at) as oldest
FROM fcm_tokens
WHERE is_active = true
GROUP BY user_id, app_type
HAVING COUNT(*) > 1
ORDER BY token_count DESC, most_recent DESC;

-- Option 5: Check for the specific failed token (if you want to manually remove it)
-- Replace 'f-xopWhoQFWY1g4TcSlM...' with the actual token prefix
SELECT 
  'Failed Token Check' as check_type,
  id,
  user_id,
  app_type,
  is_active,
  updated_at,
  LEFT(token, 30) || '...' as token_preview
FROM fcm_tokens
WHERE token LIKE 'f-xopWhoQFWY1g4TcSlM%'
  OR token LIKE 'f-xopWhoQFWY1g4TcSlM-y%';

-- To manually deactivate a specific token:
-- UPDATE fcm_tokens
-- SET is_active = false
-- WHERE token LIKE 'f-xopWhoQFWY1g4TcSlM%';
