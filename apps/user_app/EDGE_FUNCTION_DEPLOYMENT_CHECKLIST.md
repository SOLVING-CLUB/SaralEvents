# Edge Function Deployment Checklist

## ❌ Current Issue

**Error:** "Failed to fetch (api.supabase.com)"

**Meaning:** The edge function `send-push-notification` is **NOT deployed** to Supabase.

## ✅ Deployment Checklist

### Step 1: Verify Function Code Exists
- [x] Function code exists at: `apps/user_app/supabase/functions/send-push-notification/index.ts`

### Step 2: Install Supabase CLI
```bash
npm install -g supabase
```

### Step 3: Login to Supabase
```bash
supabase login
```

### Step 4: Link to Your Project
```bash
# Your project ref is: hucsihwqsuvqvbnyapdn
supabase link --project-ref hucsihwqsuvqvbnyapdn
```

### Step 5: Deploy the Function
```bash
cd apps/user_app
supabase functions deploy send-push-notification
```

**Expected Output:**
```
Deploying function send-push-notification...
Function deployed successfully
```

### Step 6: Verify Deployment
```bash
supabase functions list
```

Should show: `send-push-notification`

### Step 7: Set FCM Secret
```bash
# Get FCM Service Account JSON from Firebase Console
# Base64 encode it, then:
supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="<base64_encoded_json>"
```

### Step 8: Test
```sql
-- Run: apps/user_app/TEST_NOTIFICATION_NOW.sql
```

Should return: `{"success": true, ...}` instead of "Failed to fetch"

## 🎯 Alternative: Deploy via Dashboard

If CLI doesn't work:

1. **Go to Supabase Dashboard**
   - Navigate to: **Edge Functions**

2. **Create Function**
   - Click "Create a new function"
   - Name: `send-push-notification`

3. **Copy Code**
   - Open: `apps/user_app/supabase/functions/send-push-notification/index.ts`
   - Copy entire file content
   - Paste into dashboard editor

4. **Deploy**
   - Click "Deploy" button

5. **Set Secret**
   - Go to: **Settings > Edge Functions > Secrets**
   - Add: `FCM_SERVICE_ACCOUNT_BASE64`
   - Value: Base64-encoded FCM Service Account JSON

## 🔑 Get FCM Service Account

1. **Firebase Console** → Your Project → **Project Settings** → **Service Accounts**
2. Click **"Generate New Private Key"**
3. Download JSON file
4. Base64 encode:
   - **Linux/Mac:** `base64 -i service-account.json`
   - **Windows:** `[Convert]::ToBase64String([IO.File]::ReadAllBytes("service-account.json"))`

## ✅ After Deployment

1. **Test Function:**
   ```sql
   SELECT send_push_notification(
     'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
     'Test',
     'Test notification',
     '{"type":"test"}'::JSONB,
     NULL,
     ARRAY['user_app']::TEXT[]
   );
   ```

2. **Expected Result:**
   ```json
   {
     "success": true,
     "request_id": 12345,
     "message": "Notification request queued"
   }
   ```

3. **Check Logs:**
   ```bash
   supabase functions logs send-push-notification --tail
   ```

4. **Test Real Scenarios:**
   - Create booking → Vendor gets notification
   - Complete payment → Both apps get notifications

## 🐛 Troubleshooting

### "Function not found" after deployment
- Wait a few seconds for deployment to complete
- Check: `supabase functions list`
- Try deploying again

### "FCM service account not configured"
- Secret not set → Set `FCM_SERVICE_ACCOUNT_BASE64`
- Check: `supabase secrets list`

### Still getting "Failed to fetch"
- Check function URL is correct
- Verify project ref matches
- Check network connectivity
- Try deploying again

## 📝 Quick Reference

**Function Location:** `apps/user_app/supabase/functions/send-push-notification/`

**Deploy Command:** `supabase functions deploy send-push-notification`

**Test Query:** `apps/user_app/TEST_NOTIFICATION_NOW.sql`

**Deployment Guide:** `apps/user_app/DEPLOY_EDGE_FUNCTION.md`
