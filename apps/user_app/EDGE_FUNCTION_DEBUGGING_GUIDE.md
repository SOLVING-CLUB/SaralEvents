# Edge Function Debugging Guide

## ✅ Current Status

- ✅ FCM tokens exist and are active
- ✅ Function returns `success: true`
- ✅ Request is queued
- ❌ Notification not received

## 🔍 The Problem

Since the database function returns success but you're not receiving notifications, the issue is in the **edge function processing** or **FCM delivery**.

## 📊 Step-by-Step Debugging

### Step 1: Check Edge Function Logs (MOST IMPORTANT!)

**Go to:** Supabase Dashboard > Edge Functions > send-push-notification > **Logs**

**What to look for:**

1. **Success indicators:**
   ```
   Fetched 1 tokens for user ad73265c-4877-4a94-8394-5c455cc2a012 with appTypes: user_app
   Sent notification successfully
   ```

2. **Error indicators:**
   ```
   No active tokens found
   FCM API error: invalid token
   FCM API error: permission denied
   Failed to get access token
   ```

**The logs will tell you exactly what's wrong!**

### Step 2: Verify Token is Valid

Run this query:
```sql
-- File: apps/user_app/CHECK_EDGE_FUNCTION_EXECUTION.sql
```

**Check:**
- ✅ Token exists
- ✅ Token is active
- ✅ Token length > 50 characters (valid FCM tokens are long)
- ✅ Token was updated recently

### Step 3: Check FCM Service Account

**Verify:**
1. **Secret is set:**
   ```bash
   npx supabase secrets list
   ```
   Should show: `FCM_SERVICE_ACCOUNT_BASE64`

2. **Service Account has permissions:**
   - Go to: Firebase Console > Project Settings > Service Accounts
   - Verify service account exists
   - Check "Firebase Cloud Messaging API" is enabled

3. **Service Account JSON is valid:**
   - The JSON file you provided should match your Firebase project
   - Project ID should be: `saralevents-6fe20`

### Step 4: Test Edge Function Directly

You can test the edge function directly (bypassing the database function):

**Using Supabase Dashboard:**
1. Go to: Edge Functions > send-push-notification
2. Click "Invoke"
3. Use this payload:
   ```json
   {
     "userId": "ad73265c-4877-4a94-8394-5c455cc2a012",
     "title": "Direct Test",
     "body": "Testing edge function directly",
     "appTypes": ["user_app"]
   }
   ```
4. Check the response and logs

### Step 5: Verify Device State

**On your device:**
- ✅ App is running (not force-stopped)
- ✅ Notification permissions enabled
- ✅ Device connected to internet
- ✅ App is in foreground or background (not killed)

## 🎯 Most Likely Issues

### Issue 1: "No active tokens found"

**Cause:** Edge function query isn't finding your token

**Check:**
```sql
SELECT * FROM fcm_tokens 
WHERE user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012' 
  AND app_type = 'user_app' 
  AND is_active = true;
```

**If no results:** Token might be missing or inactive

**Fix:**
1. Open User App
2. Login (if needed)
3. Wait for token to register
4. Test again

### Issue 2: "FCM API error: invalid token"

**Cause:** FCM token is expired or invalid

**Fix:**
1. Open User App
2. Force close and reopen
3. Wait for token to refresh
4. Test again

### Issue 3: "FCM API error: permission denied"

**Cause:** FCM Service Account doesn't have permissions

**Fix:**
1. Go to Firebase Console
2. Project Settings > Service Accounts
3. Verify service account has "Firebase Cloud Messaging API" enabled
4. If not, enable it

### Issue 4: "Failed to get access token"

**Cause:** FCM Service Account JSON is invalid

**Fix:**
1. Verify JSON file is correct
2. Re-set the secret:
   ```bash
   $jsonContent = Get-Content "C:\Users\karth\Downloads\saralevents-6fe20-firebase-adminsdk-fbsvc-cf1f5a62d6.json" -Raw
   $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonContent)
   $base64 = [Convert]::ToBase64String($bytes)
   npx supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="$base64"
   ```

## 📝 Next Steps

1. **Check Dashboard logs** (this will show the exact error)
2. **Share the error message** from logs
3. **Apply the fix** based on the error
4. **Test again**

## 🔧 Quick Test

After checking logs and applying fixes:

```sql
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Test After Fix',
  'Testing after applying fixes',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

Then:
1. Check Dashboard logs immediately
2. Check device for notification
3. Share results

## 🎉 Expected Success Flow

1. Database function: `{"success":true,"request_id":X}`
2. Edge function logs: `Fetched 1 tokens for user...`
3. Edge function logs: `Sent notification successfully`
4. Device: Notification received ✅

The Dashboard logs are the key to finding the issue!
