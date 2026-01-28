# Why Notification Not Received - Diagnostic Guide

## ✅ Current Status

- ✅ Function works: `{"success":true,"request_id":6}`
- ✅ Request queued successfully
- ❌ Notification not received on device

## 🔍 Most Likely Causes

### 1. **No Active FCM Tokens** (Most Common)

The edge function might not be finding your FCM token.

**Check:**
```sql
-- Run: apps/user_app/DEBUG_NOTIFICATION_NOT_RECEIVED.sql
-- Or check directly:
SELECT * FROM fcm_tokens 
WHERE user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012' 
AND is_active = true;
```

**If no tokens found:**
1. **Open the User App** on your device
2. **Login** (if not already logged in)
3. **Wait 5-10 seconds** for token to register
4. **Check again:** `SELECT * FROM fcm_tokens WHERE user_id = '...' AND is_active = true;`
5. **Test notification again**

### 2. **Edge Function Error**

The edge function might be failing silently.

**Check Dashboard Logs:**
1. Go to: **Supabase Dashboard > Edge Functions > send-push-notification**
2. Click **"Logs"** tab
3. Look for your request (around the time you ran the test)
4. **Check for errors:**
   - `No active tokens found` → See Fix #1
   - `FCM API error: ...` → See Fix #2
   - `Invalid token` → See Fix #3

### 3. **FCM Token Expired/Invalid**

Token might be expired or invalid.

**Fix:**
1. **Open the User App**
2. **Force close and reopen** the app
3. **Wait for token to refresh**
4. **Test again**

### 4. **Device/App Issues**

**Check:**
- ✅ App is running (not force-stopped)
- ✅ Notification permissions enabled
- ✅ Device connected to internet
- ✅ App is in foreground or background

## 🔧 Quick Fixes

### Fix 1: Refresh FCM Token

1. **Open User App** on your device
2. **Login** (if needed)
3. **Wait 10 seconds** for token registration
4. **Verify token:**
   ```sql
   SELECT * FROM fcm_tokens 
   WHERE user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012' 
   AND is_active = true 
   AND updated_at >= NOW() - INTERVAL '5 minutes';
   ```
5. **Test notification again**

### Fix 2: Check Edge Function Logs

**This is the most important step!**

1. Go to: **Supabase Dashboard**
2. Navigate to: **Edge Functions** → **send-push-notification**
3. Click: **"Logs"** tab
4. **Look for your request** (should show around the time you tested)
5. **Check the error message** - it will tell you exactly what's wrong

### Fix 3: Verify FCM Token Format

```sql
-- Check if token looks valid (should be a long string)
SELECT 
  id,
  user_id,
  LEFT(token, 50) || '...' as token_preview,
  LENGTH(token) as token_length,
  app_type,
  is_active
FROM fcm_tokens
WHERE user_id = 'ad73265c-4877-4a94-8394-5c455cc2a012';
```

**Valid FCM tokens:**
- Should be a long string (100+ characters)
- Should start with letters/numbers
- Should not be NULL or empty

## 🧪 Test After Fixes

1. **Ensure app is open** on device
2. **Run test:**
   ```sql
   SELECT send_push_notification(
     'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
     'Test After Fix',
     'Testing after refreshing token',
     '{"type":"test"}'::JSONB,
     NULL,
     ARRAY['user_app']::TEXT[]
   );
   ```
3. **Immediately check Dashboard logs**
4. **Check device** for notification

## 📊 Diagnostic Checklist

Run this to check everything:

```sql
-- File: apps/user_app/DEBUG_NOTIFICATION_NOT_RECEIVED.sql
```

This will show:
- ✅ Token status
- ✅ Token freshness
- ✅ Recent requests
- ✅ User token verification

## 🎯 Most Important Step

**Check Supabase Dashboard Logs!**

The logs will show you the exact error:
- `No active tokens found` → User needs to login to app
- `FCM API error: invalid token` → Token expired, refresh it
- `FCM API error: permission denied` → FCM Service Account issue
- `Sent notification successfully` → Notification was sent, check device

## 📝 Next Steps

1. **Check Dashboard logs** (most important!)
2. **Share the error message** from logs
3. **Apply the fix** based on the error
4. **Test again**

The function is working, so the issue is in edge function processing or FCM delivery. The Dashboard logs will show exactly what's wrong.
