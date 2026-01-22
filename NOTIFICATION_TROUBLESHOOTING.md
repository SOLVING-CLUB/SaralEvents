# Notification System Troubleshooting Guide

If notifications are not being processed, follow these steps:

## Step 1: Run Diagnostics

Run the diagnostic script to identify issues:

```sql
-- Run: apps/user_app/diagnose_notification_issues.sql
```

This will check:
- ✅ pg_net extension status
- ✅ Environment variables (app.supabase_url, app.supabase_service_role_key)
- ✅ app_type column existence
- ✅ Trigger and function existence
- ✅ FCM token registration
- ✅ Recent database activity

## Step 2: Fix Common Issues

Run the fix script to resolve common problems:

```sql
-- Run: apps/user_app/fix_notification_issues.sql
```

This will:
- Enable pg_net extension
- Add app_type column if missing
- Create necessary indexes
- Backfill app_type for existing tokens

## Step 3: Set Environment Variables

**CRITICAL:** The notification system requires these environment variables to be set:

```sql
-- Replace with your actual Supabase project URL
ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';

-- Replace with your actual service role key (from Supabase Dashboard > Settings > API)
ALTER DATABASE postgres SET app.supabase_service_role_key = 'your-service-role-key-here';
```

**To find your service role key:**
1. Go to Supabase Dashboard
2. Select your project
3. Go to Settings > API
4. Copy the "service_role" key (NOT the anon key)

## Step 4: Verify Edge Function

1. **Check if Edge Function is deployed:**
   - Go to Supabase Dashboard > Edge Functions
   - Verify `send-push-notification` function exists

2. **Check Edge Function secrets:**
   - Go to Edge Functions > `send-push-notification` > Settings
   - Verify `FCM_SERVICE_ACCOUNT_BASE64` secret is set
   - This should be your Firebase service account JSON (base64 encoded)

3. **Test Edge Function manually:**
   ```sql
   -- Test the Edge Function directly
   SELECT net.http_post(
     url := 'https://your-project.supabase.co/functions/v1/send-push-notification',
     headers := jsonb_build_object(
       'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY',
       'Content-Type', 'application/json'
     ),
     body := jsonb_build_object(
       'userId', 'YOUR_USER_ID',
       'title', 'Test Notification',
       'body', 'This is a test',
       'appTypes', ARRAY['user_app']
     )
   );
   ```

## Step 5: Check FCM Token Registration

1. **Verify tokens are registered:**
   ```sql
   SELECT 
     user_id,
     app_type,
     device_type,
     is_active,
     created_at
   FROM fcm_tokens
   WHERE is_active = true
   ORDER BY updated_at DESC;
   ```

2. **Check if app_type is set correctly:**
   ```sql
   SELECT 
     app_type,
     COUNT(*) as count
   FROM fcm_tokens
   WHERE is_active = true
   GROUP BY app_type;
   ```

3. **Backfill app_type if needed:**
   ```sql
   -- For vendor tokens
   UPDATE fcm_tokens
   SET app_type = 'vendor_app'
   WHERE user_id IN (SELECT user_id FROM vendor_profiles)
     AND (app_type IS NULL OR app_type <> 'vendor_app');

   -- For user tokens
   UPDATE fcm_tokens
   SET app_type = 'user_app'
   WHERE user_id IN (
     SELECT user_id FROM user_profiles
     WHERE user_id NOT IN (SELECT user_id FROM vendor_profiles)
   )
     AND (app_type IS NULL OR app_type <> 'user_app');
   ```

## Step 6: Test Database Triggers

1. **Test booking status change trigger:**
   ```sql
   -- Update a booking status and check if trigger fires
   UPDATE bookings
   SET status = 'confirmed',
       updated_at = NOW()
   WHERE id = 'YOUR_BOOKING_ID'
   RETURNING id, status;
   ```

2. **Check trigger execution:**
   ```sql
   -- Check pg_net request queue for recent calls
   SELECT 
     id,
     url,
     method,
     status_code,
     created_at
   FROM net.http_request_queue
   WHERE created_at >= NOW() - INTERVAL '1 hour'
   ORDER BY created_at DESC;
   ```

## Step 7: Check Application Logs

### User App
- Check Flutter console for:
  - `✅ PushNotificationService: Token registered in database`
  - `📤 [User App] send-push-notification: ...`
  - `✅ [User App] Notification sent successfully`

### Vendor App
- Check Flutter console for:
  - `✅ [Vendor] PushNotificationService: Token registered in database`
  - `📤 [Vendor] send-push-notification: ...`
  - `✅ [Vendor] Notification sent successfully`

### Edge Function Logs
- Go to Supabase Dashboard > Edge Functions > `send-push-notification` > Logs
- Check for errors or warnings

## Step 8: Common Issues and Solutions

### Issue: "No active tokens found"
**Solution:**
- Ensure user is logged in
- Open the app to register FCM token
- Check `fcm_tokens` table for the user's token
- Verify `is_active = true` and `app_type` is set

### Issue: "Push notifications skipped: missing app.supabase_url"
**Solution:**
- Set environment variables (see Step 3)
- Restart Supabase or reconnect to database

### Issue: "Failed to send push notification via pg_net"
**Solution:**
- Enable pg_net extension: `CREATE EXTENSION IF NOT EXISTS pg_net;`
- Check if extension is enabled: `SELECT * FROM pg_extension WHERE extname = 'pg_net';`

### Issue: Notifications go to wrong app
**Solution:**
- Verify `app_type` is set correctly in `fcm_tokens` table
- Check that `appTypes` parameter is passed correctly in notification calls
- Run backfill script (see Step 5)

### Issue: Duplicate notifications
**Solution:**
- Ensure app code doesn't send notifications that are handled by database triggers
- Check for duplicate triggers: `SELECT * FROM information_schema.triggers WHERE trigger_name LIKE '%notification%';`

### Issue: Triggers not firing
**Solution:**
- Verify triggers exist: `SELECT * FROM information_schema.triggers WHERE event_object_table = 'bookings';`
- Check trigger conditions match your data updates
- Test with a manual UPDATE statement

## Step 9: Manual Test

Test the complete flow manually:

```sql
-- 1. Get a test user ID and vendor ID
SELECT id, user_id FROM vendor_profiles LIMIT 1;
SELECT id FROM auth.users LIMIT 1;

-- 2. Test sending notification directly
SELECT send_push_notification(
  'USER_ID_HERE'::UUID,
  'Test Notification',
  'This is a manual test',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);

-- 3. Check if request was queued
SELECT * FROM net.http_request_queue 
WHERE created_at >= NOW() - INTERVAL '1 minute'
ORDER BY created_at DESC;
```

## Step 10: Verify Complete Setup

Run this checklist:

- [ ] pg_net extension is enabled
- [ ] Environment variables are set (app.supabase_url, app.supabase_service_role_key)
- [ ] app_type column exists in fcm_tokens table
- [ ] FCM tokens are registered with correct app_type
- [ ] Edge Function is deployed and has FCM_SERVICE_ACCOUNT_BASE64 secret
- [ ] All triggers exist and are active
- [ ] Functions exist and can be called
- [ ] Test notification works manually

## Still Not Working?

1. **Check Supabase logs:**
   - Dashboard > Logs > Database
   - Look for warnings or errors related to notifications

2. **Check Edge Function logs:**
   - Dashboard > Edge Functions > send-push-notification > Logs
   - Look for errors or failed requests

3. **Verify Firebase setup:**
   - Check Firebase Console > Cloud Messaging
   - Verify service account key is correct
   - Test FCM directly from Firebase Console

4. **Check network/firewall:**
   - Ensure Supabase can reach Firebase FCM API
   - Check if any firewall rules are blocking requests
