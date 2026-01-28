# Troubleshoot: Notification Not Received

## ✅ Good News

Your function is working: `{"success":true,"request_id":6}`

This means:
- ✅ Function executed successfully
- ✅ Request was queued to edge function
- ✅ Edge function should be processing it

## 🔍 Why You're Not Receiving Notifications

Since the function returns success but you're not getting notifications, the issue is likely:

### 1. **Edge Function Error** (Most Likely)
The edge function might be failing when trying to send to FCM.

**Check:** Supabase Dashboard > Edge Functions > send-push-notification > Logs

**Look for:**
- ❌ `No active tokens found` → User needs to login to app
- ❌ `FCM API error` → FCM Service Account issue
- ❌ `Invalid token` → Token expired, user needs to login again
- ❌ `Token not found` → Token doesn't exist in database

### 2. **FCM Token Issues**

**Check token status:**
```sql
-- Run: apps/user_app/DEBUG_NOTIFICATION_NOT_RECEIVED.sql
```

**Common issues:**
- Token is inactive → User needs to login to app
- Token is expired → App needs to refresh token
- Token doesn't exist → User hasn't logged in to app

### 3. **Device/App Issues**

**Check:**
- ✅ App is running (not force-stopped)
- ✅ Notification permissions are enabled
- ✅ Device is connected to internet
- ✅ App is in foreground or background (not killed)

### 4. **FCM Service Account Issue**

**Verify:**
- ✅ Secret is set: `npx supabase secrets list` (already checked ✅)
- ✅ Service Account JSON is valid
- ✅ Service Account has FCM permissions in Firebase Console

## 🔧 Step-by-Step Fix

### Step 1: Check Edge Function Logs

**Go to:** Supabase Dashboard > Edge Functions > send-push-notification > Logs

**Look for your request (around the time you ran the test)**

**Success indicators:**
- ✅ `Fetched 1 tokens for user...`
- ✅ `Sent notification successfully`
- ✅ `Notification sent to FCM`

**Error indicators:**
- ❌ `No active tokens found` → See Step 2
- ❌ `FCM API error: ...` → See Step 3
- ❌ `Invalid token` → See Step 2

### Step 2: Fix Token Issues

**If logs show "No active tokens found":**

1. **Open the User App** on your device
2. **Login** (if not already logged in)
3. **Wait a few seconds** for token to register
4. **Verify token is registered:**
   ```sql
   SELECT * FROM fcm_tokens 
   WHERE user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012' 
   AND is_active = true;
   ```
5. **Test again**

### Step 3: Fix FCM API Errors

**If logs show FCM API errors:**

1. **Verify Service Account has permissions:**
   - Go to Firebase Console
   - Check Service Account has "Firebase Cloud Messaging API" enabled

2. **Verify Service Account JSON is correct:**
   - The JSON file you provided should be valid
   - Check if it's the correct project: `saralevents-6fe20`

3. **Re-set the secret:**
   ```bash
   # Re-encode and set
   $jsonContent = Get-Content "C:\Users\karth\Downloads\saralevents-6fe20-firebase-adminsdk-fbsvc-cf1f5a62d6.json" -Raw
   $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonContent)
   $base64 = [Convert]::ToBase64String($bytes)
   npx supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="$base64"
   ```

### Step 4: Verify App State

**On your device:**
1. **Open the User App**
2. **Check notification permissions:**
   - Android: Settings > Apps > Your App > Notifications
   - iOS: Settings > Notifications > Your App
3. **Ensure app is running** (not force-stopped)
4. **Keep app open** or in background when testing

## 🧪 Test Again After Fixes

1. **Ensure app is open** on your device
2. **Run test query:**
   ```sql
   SELECT send_push_notification(
     'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
     'Test Notification',
     'Testing after fixes',
     '{"type":"test"}'::JSONB,
     NULL,
     ARRAY['user_app']::TEXT[]
   );
   ```
3. **Check Dashboard logs** immediately
4. **Check your device** for notification

## 📊 Diagnostic Queries

Run these to check:

```sql
-- Check token status
SELECT * FROM fcm_tokens 
WHERE user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012';

-- Check recent requests
SELECT * FROM net.http_request_queue 
ORDER BY id DESC 
LIMIT 5;
```

## 🎯 Most Likely Issue

Based on your situation, the most likely issue is:

**"No active tokens found"** in edge function logs

**Solution:**
1. Open the User App on your device
2. Login (if needed)
3. Wait for token to register
4. Verify token exists: `SELECT * FROM fcm_tokens WHERE user_id = '...' AND is_active = true;`
5. Test again

## 📝 Next Steps

1. **Check Dashboard logs** first (this will tell you exactly what's wrong)
2. **Fix the issue** based on the error message
3. **Test again**
4. **Share the error message** from logs if you need help

The function is working, so the issue is in the edge function processing or FCM delivery. Check the Dashboard logs to see the exact error.
