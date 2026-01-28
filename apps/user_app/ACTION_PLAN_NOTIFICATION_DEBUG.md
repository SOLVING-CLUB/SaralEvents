# Action Plan: Debug Notification Not Received

## ✅ What We Know

- ✅ FCM tokens exist and are active (7 tokens, 1 recent user_app token)
- ✅ Database function returns `success: true`
- ✅ Request is queued (request_id: 6)
- ✅ Payload is correct
- ❌ Notification not received on device

## 🎯 Root Cause Analysis

Since everything on the database side is working, the issue is in:
1. **Edge function processing** (most likely)
2. **FCM API delivery** (less likely)
3. **Device/app state** (possible)

## 📊 Step 1: Check Dashboard Logs (CRITICAL!)

**This is the most important step!**

1. **Go to:** [Supabase Dashboard](https://supabase.com/dashboard)
2. **Navigate to:** Your Project > Edge Functions > `send-push-notification`
3. **Click:** "Logs" tab
4. **Look for:** Your request (around the time you ran the test - request_id 6)
5. **Check the log message** - it will tell you exactly what happened

### What to Look For:

**✅ Success:**
```
Fetched 1 tokens for user ad73265c-4877-4a94-8394-5c455cc2a012 with appTypes: user_app
Sent notification successfully
```

**❌ Errors:**

**Error 1: No tokens found**
```
No active tokens found
```
**Fix:** Token query issue - but we know tokens exist, so this is unlikely

**Error 2: FCM API error**
```
FCM API error: invalid token
FCM API error: permission denied
```
**Fix:** 
- `invalid token` → Token expired, user needs to open app
- `permission denied` → FCM Service Account permissions issue

**Error 3: Access token error**
```
Failed to get access token
```
**Fix:** FCM Service Account JSON issue - re-set the secret

**Error 4: Service account not configured**
```
FCM service account not configured
```
**Fix:** Secret not set - but we already set it, so unlikely

## 🔍 Step 2: Test Edge Function via Dashboard

If logs don't show your request, test directly:

1. **Go to:** Dashboard > Edge Functions > `send-push-notification`
2. **Click:** "Invoke" button
3. **Paste this payload:**
   ```json
   {
     "userId": "ad73265c-4877-4a94-8394-5c455cc2a012",
     "title": "Dashboard Test",
     "body": "Testing directly from Dashboard",
     "appTypes": ["user_app"],
     "data": {
       "type": "test"
     }
   }
   ```
4. **Click:** "Invoke"
5. **Check:**
   - Response (shows success/failure)
   - Logs tab (shows detailed execution)

## 🔧 Step 3: Common Fixes

### Fix 1: Token Expired

**If logs show "FCM API error: invalid token":**

1. **Open User App** on your device
2. **Force close** the app
3. **Reopen** the app
4. **Wait 10 seconds** for token refresh
5. **Test again**

### Fix 2: FCM Service Account Permissions

**If logs show "FCM API error: permission denied":**

1. **Go to:** [Firebase Console](https://console.firebase.google.com)
2. **Select:** Project `saralevents-6fe20`
3. **Go to:** Project Settings > Service Accounts
4. **Verify:** Service account `firebase-adminsdk-fbsvc@saralevents-6fe20.iam.gserviceaccount.com` exists
5. **Check:** "Firebase Cloud Messaging API" is enabled
6. **If not enabled:** Enable it

### Fix 3: Re-set FCM Secret

**If logs show "Failed to get access token":**

```powershell
$jsonContent = Get-Content "C:\Users\karth\Downloads\saralevents-6fe20-firebase-adminsdk-fbsvc-cf1f5a62d6.json" -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonContent)
$base64 = [Convert]::ToBase64String($bytes)
npx supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="$base64"
```

### Fix 4: Device/App State

**Check on your device:**
- ✅ App is running (not force-stopped)
- ✅ Notification permissions enabled
- ✅ Device connected to internet
- ✅ App is in foreground or background

## 📝 Step 4: Share Results

After checking Dashboard logs, share:
1. **The log message** (exact error or success message)
2. **The response** (if you tested via Dashboard)
3. **Any errors** you see

## 🎯 Most Likely Scenario

Based on your setup:
- ✅ Tokens exist
- ✅ Function works
- ✅ Payload correct

**Most likely:** Edge function is processing but FCM API is rejecting the token or there's a permissions issue.

**Check Dashboard logs to confirm!**

## 🚀 Quick Test After Fixes

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
1. **Immediately check Dashboard logs**
2. **Check device** for notification
3. **Share results**

---

## 📌 Summary

**Next Action:** Check Supabase Dashboard > Edge Functions > send-push-notification > Logs

**This will show you exactly what's wrong!**
