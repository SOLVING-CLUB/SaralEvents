# Push Notifications Fix Guide

This guide will help you fix push notifications for both User App and Vendor App.

## 🔍 Common Issues

1. **Missing `app_type` column** in `fcm_tokens` table
2. **pg_net extension not enabled**
3. **Environment variables not set**
4. **Edge function not deployed or misconfigured**
5. **FCM Service Account not configured**

## ✅ Step-by-Step Fix

### Step 1: Run Database Fix Script

Run the SQL script in Supabase SQL Editor:

```sql
-- File: apps/user_app/fix_push_notifications.sql
```

This script will:
- ✅ Enable pg_net extension
- ✅ Add `app_type` column to `fcm_tokens` table
- ✅ Create necessary indexes
- ✅ Backfill `app_type` for existing tokens

### Step 2: Set Environment Variables

In Supabase SQL Editor, run these commands (replace with your actual values):

```sql
-- Get these from Supabase Dashboard > Settings > API
ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';
ALTER DATABASE postgres SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';
```

**To find these values:**
1. Go to Supabase Dashboard
2. Navigate to Settings > API
3. Copy:
   - **Project URL** → Use for `supabase_url`
   - **service_role key** → Use for `supabase_service_role_key` (⚠️ Keep this secret!)

### Step 3: Deploy Edge Function

The edge function is located at: `apps/user_app/supabase/functions/send-push-notification`

**Deploy using Supabase CLI:**

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy the function
supabase functions deploy send-push-notification
```

### Step 4: Configure FCM Service Account

1. **Get FCM Service Account JSON:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to Project Settings > Service Accounts
   - Click "Generate New Private Key"
   - Download the JSON file

2. **Base64 Encode the JSON:**
   
   **On Linux/Mac:**
   ```bash
   base64 -i service-account.json
   ```
   
   **On Windows (PowerShell):**
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("service-account.json"))
   ```

3. **Set as Supabase Secret:**
   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="<paste_base64_encoded_string_here>"
   ```

### Step 5: Verify Setup

Run these verification queries in Supabase SQL Editor:

```sql
-- Check if app_type column exists
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'fcm_tokens' AND column_name = 'app_type'
    )
    THEN '✅ app_type column exists'
    ELSE '❌ app_type column does NOT exist'
  END AS app_type_column_status;

-- Check active tokens by app type
SELECT 
  app_type,
  COUNT(*) as token_count,
  COUNT(DISTINCT user_id) as unique_users
FROM fcm_tokens
WHERE is_active = true
GROUP BY app_type;

-- Check pg_net extension
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_extension WHERE extname = 'pg_net'
    )
    THEN '✅ pg_net extension enabled'
    ELSE '❌ pg_net extension NOT enabled'
  END AS pg_net_status;
```

## 🧪 Testing Push Notifications

### Test from Database Trigger

You can test by manually calling the notification function:

```sql
-- Test notification for a specific user
SELECT send_push_notification(
  'USER_ID_HERE'::UUID,
  'Test Notification',
  'This is a test notification',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]  -- or ['vendor_app'] for vendor app
);
```

### Test from App

1. **User App:**
   - Login to the user app
   - Check logs for: `✅ PushNotificationService: Token registered in database`
   - Verify token is in `fcm_tokens` table with `app_type = 'user_app'`

2. **Vendor App:**
   - Login to the vendor app
   - Check logs for: `✅ [Vendor] PushNotificationService: Token registered in database`
   - Verify token is in `fcm_tokens` table with `app_type = 'vendor_app'`

## 🔧 Troubleshooting

### Issue: Tokens not registering

**Check:**
1. User is logged in (both apps check for authenticated user)
2. Firebase is properly initialized (check logs for Firebase initialization)
3. Permissions are granted (check device notification settings)

**Debug:**
- Check app logs for error messages
- Verify `fcm_tokens` table has proper RLS policies
- Check if token upsert is successful

### Issue: Notifications not being sent

**Check:**
1. Edge function is deployed: `supabase functions list`
2. FCM secret is set: `supabase secrets list`
3. Database triggers are active (check `information_schema.triggers`)
4. `app_type` is correctly set in tokens

**Debug:**
- Check edge function logs: `supabase functions logs send-push-notification`
- Verify tokens exist with correct `app_type`
- Test edge function directly with a test request

### Issue: Notifications going to wrong app

**Check:**
1. `app_type` is correctly set when registering tokens
2. Edge function is filtering by `appTypes` parameter
3. Database triggers are passing correct `appTypes` array

**Fix:**
- Re-run the fix script to backfill `app_type`
- Verify both apps are setting `app_type` correctly (they are!)

## 📱 App-Specific Notes

### User App
- Sets `app_type = 'user_app'` when registering tokens
- Initializes push notifications when user logs in
- Located in: `apps/user_app/lib/services/push_notification_service.dart`

### Vendor App
- Sets `app_type = 'vendor_app'` when registering tokens
- Initializes push notifications when vendor logs in
- Located in: `saral_events_vendor_app/lib/services/push_notification_service.dart`

## ✅ Checklist

- [ ] Run `fix_push_notifications.sql` script
- [ ] Set environment variables (`supabase_url` and `supabase_service_role_key`)
- [ ] Deploy edge function `send-push-notification`
- [ ] Set FCM Service Account secret (`FCM_SERVICE_ACCOUNT_BASE64`)
- [ ] Verify `app_type` column exists and has data
- [ ] Verify pg_net extension is enabled
- [ ] Test token registration in both apps
- [ ] Test sending a notification

## 📞 Support

If issues persist:
1. Check Supabase logs for errors
2. Check edge function logs
3. Verify Firebase project configuration
4. Check device notification permissions
