# Push Notifications Troubleshooting Guide

Since your database setup is ✅ good, let's check the other components.

## 🔍 Quick Diagnostic Checklist

### ✅ Database Setup (Already Verified)
- [x] pg_net extension enabled
- [x] app_type column exists
- [x] Tokens are registered correctly

### ⚠️ Remaining Checks

#### 1. **Edge Function Deployment**
Check if the edge function is deployed:

```bash
supabase functions list
```

If `send-push-notification` is not listed, deploy it:

```bash
cd apps/user_app
supabase functions deploy send-push-notification
```

#### 2. **FCM Service Account Secret**
Check if the FCM secret is set:

```bash
supabase secrets list
```

If `FCM_SERVICE_ACCOUNT_BASE64` is missing, set it:

```bash
# First, get your FCM Service Account JSON from Firebase Console
# Then base64 encode it and set as secret:
supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="<base64_encoded_json>"
```

#### 3. **Environment Variables**
Even though the verification shows they're set, let's verify they're correct:

```sql
-- Check current values
SELECT 
  current_setting('app.supabase_url', true) as supabase_url,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
    THEN '✅ Set (hidden for security)'
    ELSE '❌ NOT set'
  END as service_role_key_status;
```

If not set correctly, update them:

```sql
ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT.supabase.co';
ALTER DATABASE postgres SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';
```

#### 4. **Test the Function**
Run the test script to verify everything works:

```sql
-- File: apps/user_app/test_push_notifications.sql
```

## 🧪 Step-by-Step Testing

### Step 1: Test Database Function

```sql
-- Get a user ID with active tokens
SELECT 
  u.id as user_id,
  u.email,
  ft.app_type
FROM auth.users u
JOIN fcm_tokens ft ON ft.user_id = u.id
WHERE ft.is_active = true
LIMIT 1;

-- Test send_push_notification (replace USER_ID)
SELECT send_push_notification(
  'USER_ID_FROM_ABOVE'::UUID,
  'Test Notification',
  'Testing push notifications',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

**Expected Result:**
```json
{
  "success": true,
  "request_id": 12345,
  "message": "Notification request queued"
}
```

### Step 2: Check pg_net Request Queue

```sql
SELECT 
  id,
  url,
  status,
  error_msg,
  created_at
FROM net.http_request_queue
WHERE created_at >= NOW() - INTERVAL '5 minutes'
ORDER BY created_at DESC
LIMIT 10;
```

**If you see errors:**
- `status = 'ERROR'` → Check `error_msg` column
- Common errors:
  - `404 Not Found` → Edge function not deployed
  - `401 Unauthorized` → Service role key incorrect
  - `500 Internal Server Error` → Edge function error (check logs)

### Step 3: Check Edge Function Logs

```bash
supabase functions logs send-push-notification --tail
```

**Look for:**
- ✅ `FCM service account not configured` → Set FCM_SERVICE_ACCOUNT_BASE64 secret
- ✅ `No active tokens found` → User has no registered tokens
- ✅ `FCM API error` → Check FCM Service Account JSON

### Step 4: Verify App Token Registration

**In User App:**
1. Login to the app
2. Check logs for: `✅ PushNotificationService: Token registered in database`
3. Verify in database:
```sql
SELECT * FROM fcm_tokens 
WHERE user_id = 'YOUR_USER_ID' 
  AND app_type = 'user_app' 
  AND is_active = true;
```

**In Vendor App:**
1. Login to the app
2. Check logs for: `✅ [Vendor] PushNotificationService: Token registered in database`
3. Verify in database:
```sql
SELECT * FROM fcm_tokens 
WHERE user_id = 'YOUR_USER_ID' 
  AND app_type = 'vendor_app' 
  AND is_active = true;
```

## 🐛 Common Issues & Solutions

### Issue 1: "No active tokens found"
**Cause:** User hasn't logged in or token registration failed

**Solution:**
1. Ensure user is logged in
2. Check app logs for token registration errors
3. Verify Firebase is initialized correctly
4. Check device notification permissions

### Issue 2: "Edge function not found (404)"
**Cause:** Edge function not deployed

**Solution:**
```bash
supabase functions deploy send-push-notification
```

### Issue 3: "FCM service account not configured"
**Cause:** FCM_SERVICE_ACCOUNT_BASE64 secret not set

**Solution:**
1. Get FCM Service Account JSON from Firebase Console
2. Base64 encode it
3. Set as secret: `supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="..."`

### Issue 4: "Unauthorized (401)"
**Cause:** Service role key incorrect or not set

**Solution:**
```sql
ALTER DATABASE postgres SET app.supabase_service_role_key = 'CORRECT_KEY';
```

### Issue 5: Notifications sent but not received
**Possible Causes:**
1. Device notification permissions denied
2. App not running or in background
3. FCM token expired (should auto-refresh)
4. Wrong app_type filter

**Solution:**
1. Check device notification settings
2. Ensure app has notification permissions
3. Verify token is active: `SELECT * FROM fcm_tokens WHERE is_active = true`
4. Test with correct app_type: `ARRAY['user_app']` or `ARRAY['vendor_app']`

## 📊 Monitoring

### Check Recent Notifications
```sql
SELECT 
  COUNT(*) as total_requests,
  COUNT(CASE WHEN status = 'SUCCESS' THEN 1 END) as successful,
  COUNT(CASE WHEN status = 'ERROR' THEN 1 END) as failed
FROM net.http_request_queue
WHERE created_at >= NOW() - INTERVAL '1 hour';
```

### Check Token Health
```sql
SELECT 
  app_type,
  device_type,
  COUNT(*) as token_count,
  COUNT(CASE WHEN updated_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_tokens
FROM fcm_tokens
WHERE is_active = true
GROUP BY app_type, device_type;
```

## ✅ Final Verification

Run this complete test:

1. **Database Function Test:**
   ```sql
   -- Run test_push_notifications.sql
   ```

2. **Edge Function Test:**
   ```bash
   # Test via Supabase Dashboard or CLI
   supabase functions invoke send-push-notification --body '{"userId":"...","title":"Test","body":"Test","appTypes":["user_app"]}'
   ```

3. **End-to-End Test:**
   - Create a booking/order
   - Trigger a notification event
   - Verify notification is received

## 📞 Still Not Working?

If after all these checks notifications still don't work:

1. **Check Firebase Configuration:**
   - Verify `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is correct
   - Ensure Firebase project is linked correctly

2. **Check App Logs:**
   - Look for Firebase initialization errors
   - Check for token registration errors
   - Verify notification permission status

3. **Check Edge Function Logs:**
   ```bash
   supabase functions logs send-push-notification --tail 50
   ```

4. **Test FCM Directly:**
   - Use Firebase Console > Cloud Messaging > Send test message
   - Use the FCM token from database
