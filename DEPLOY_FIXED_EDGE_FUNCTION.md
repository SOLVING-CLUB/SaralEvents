# Deploy Fixed Edge Function - Fix jws Compatibility Issue

## 🔧 **PROBLEM FIXED**

**Error:** `TypeError: Object prototype may only be an Object or null: undefined`  
**Cause:** `google-auth-library` uses `jws` library which is incompatible with Deno

**Solution:** Replaced `google-auth-library` with Deno-compatible JWT implementation using `djwt`

---

## ✅ **CHANGES MADE**

1. **Removed:** `google-auth-library@9.0.0` (incompatible with Deno)
2. **Added:** `djwt@v2.8` (Deno-compatible JWT library)
3. **Implemented:** Manual OAuth2 JWT assertion flow
4. **Added:** Token caching to reduce API calls

---

## 🚀 **DEPLOY THE FIXED FUNCTION**

### **Method 1: Using Supabase CLI (Recommended)**

```bash
# Navigate to project
cd C:\Users\karth\OneDrive\Desktop\SOLVING_CLUB\SaralEvents\apps\user_app

# Deploy the fixed function
npx supabase functions deploy send-push-notification
```

**Expected Output:**
```
Deploying function send-push-notification...
Function deployed successfully
```

### **Method 2: Using Supabase Dashboard**

1. Go to Supabase Dashboard > **Edge Functions** > **send-push-notification**
2. Click **Edit** or **Settings**
3. Copy the entire content from: `apps/user_app/supabase/functions/send-push-notification/index.ts`
4. Paste into the editor
5. Click **Deploy** or **Save**

---

## 🧪 **TEST AFTER DEPLOYMENT**

### **Step 1: Test via Dashboard**

1. Go to Supabase Dashboard > **Edge Functions** > **send-push-notification**
2. Click **Test** button
3. Select **POST** method
4. Use this payload:

```json
{
  "userId": "ad73265c-4877-4a94-8394-5c455cc2a012",
  "title": "Test After Fix",
  "body": "Testing fixed edge function",
  "appTypes": ["user_app"]
}
```

5. Click **Run**
6. **Expected:** Status 200 with response showing `"sent": 1`

### **Step 2: Test via Database Function**

```sql
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Test After Fix',
  'Testing fixed edge function via database',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

**Expected:** `{"success":true,"request_id":...}`

### **Step 3: Check Logs**

1. Go to **Logs** tab in edge function
2. Should see: `Fetched 1 tokens for user ... with appTypes: user_app`
3. Should see: Success messages (no errors)

---

## ✅ **WHAT'S FIXED**

- ✅ **No more jws compatibility error**
- ✅ **Uses Deno-compatible JWT library (djwt)**
- ✅ **Proper OAuth2 JWT assertion flow**
- ✅ **Token caching for better performance**
- ✅ **Same functionality as before**

---

## 🔍 **IF YOU STILL SEE ERRORS**

### **Error: "Failed to get access token"**
- Check FCM_SERVICE_ACCOUNT_BASE64 secret is set
- Verify service account JSON is valid
- Check private key format in service account

### **Error: "FCM API error"**
- Verify FCM API is enabled in Google Cloud Console
- Check service account has Firebase Cloud Messaging API permission
- Verify project_id matches Firebase project

### **Error: "No active tokens found"**
- User needs to login to app
- App needs to register FCM token
- Check fcm_tokens table has active tokens

---

## 📋 **VERIFICATION CHECKLIST**

After deployment:
- [ ] Function deploys successfully
- [ ] Test via Dashboard returns 200
- [ ] Test via database function returns success
- [ ] Logs show successful execution
- [ ] Notification received in app

---

**Deploy the function and test it!**
