# Deploy Edge Function - Fix "Failed to fetch" Error

## 🔍 Error Meaning

**"Failed to fetch (api.supabase.com)"** means:
- ❌ Edge function `send-push-notification` is **NOT deployed**
- OR the function URL is incorrect
- OR there's a network/connectivity issue

## ✅ Solution: Deploy Edge Function

### Method 1: Using Supabase CLI (Recommended)

```bash
# 1. Install Supabase CLI (if not already installed)
npm install -g supabase

# 2. Login to Supabase
supabase login

# 3. Link to your project
# Replace 'hucsihwqsuvqvbnyapdn' with your actual project ref
supabase link --project-ref hucsihwqsuvqvbnyapdn

# 4. Navigate to user app directory
cd apps/user_app

# 5. Deploy the edge function
supabase functions deploy send-push-notification

# 6. Set FCM Service Account secret
# First, get your FCM Service Account JSON from Firebase Console
# Then base64 encode it:
#   Linux/Mac: base64 -i service-account.json
#   Windows: [Convert]::ToBase64String([IO.File]::ReadAllBytes("service-account.json"))
supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="<paste_base64_encoded_json_here>"
```

### Method 2: Using Supabase Dashboard

1. **Go to Supabase Dashboard**
   - Navigate to: **Edge Functions**

2. **Create New Function**
   - Click "Create a new function"
   - Name: `send-push-notification`

3. **Copy Function Code**
   - Open: `apps/user_app/supabase/functions/send-push-notification/index.ts`
   - Copy all the code
   - Paste into the function editor

4. **Deploy**
   - Click "Deploy"

5. **Set Secret**
   - Go to: **Settings > Edge Functions > Secrets**
   - Add secret: `FCM_SERVICE_ACCOUNT_BASE64`
   - Value: Your base64-encoded FCM Service Account JSON

## 🔑 Get FCM Service Account

1. **Go to Firebase Console**
   - https://console.firebase.google.com/
   - Select your project

2. **Get Service Account**
   - Go to: **Project Settings > Service Accounts**
   - Click: **"Generate New Private Key"**
   - Download the JSON file

3. **Base64 Encode**
   
   **Linux/Mac:**
   ```bash
   base64 -i service-account.json
   ```
   
   **Windows (PowerShell):**
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("service-account.json"))
   ```

4. **Set as Secret**
   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="<paste_base64_string_here>"
   ```

## ✅ Verify Deployment

### Check Function is Deployed

```bash
supabase functions list
```

Should show: `send-push-notification`

### Test the Function

```sql
-- Run this test query
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Test Notification',
  'Testing edge function',
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

### Check Edge Function Logs

```bash
supabase functions logs send-push-notification --tail
```

## 🐛 Troubleshooting

### Error: "Function not found"
- Function isn't deployed → Deploy it using steps above

### Error: "FCM service account not configured"
- Secret isn't set → Set `FCM_SERVICE_ACCOUNT_BASE64` secret

### Error: "No active tokens found"
- User doesn't have FCM token → User needs to login to app

### Error: "401 Unauthorized"
- Service role key is wrong → Check the key in function code

## 📝 Files Reference

- **Edge Function Code:** `apps/user_app/supabase/functions/send-push-notification/index.ts`
- **Test Query:** `apps/user_app/TEST_NOTIFICATION_NOW.sql`
- **Fix Script:** `apps/user_app/FIX_EDGE_FUNCTION_ERROR.sql`

## 🎯 After Deployment

Once deployed:
1. ✅ Test manually using `TEST_NOTIFICATION_NOW.sql`
2. ✅ Create a booking → Vendor should get notification
3. ✅ Complete payment → Both apps should get notifications
