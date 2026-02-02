# Deploy with Better Error Logging

## 🔧 **FIX APPLIED**

I've added comprehensive error logging throughout the edge function to help identify where it's failing.

**Added logging for:**
- ✅ Private key import
- ✅ JWT creation
- ✅ OAuth2 token request
- ✅ FCM message sending
- ✅ Overall notification results

---

## 🚀 **DEPLOY AND TEST**

### **Step 1: Deploy Updated Code**

```bash
cd apps/user_app
npx supabase functions deploy send-push-notification
```

Or via Dashboard:
1. Copy updated code from `apps/user_app/supabase/functions/send-push-notification/index.ts`
2. Paste into Dashboard editor
3. Deploy

### **Step 2: Test**

Run this query:

```sql
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Test with Logging',
  'Testing with enhanced error logging',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

### **Step 3: Check Logs**

1. Go to Supabase Dashboard > **Edge Functions** > **send-push-notification** > **Logs**
2. Look for:
   - "Successfully imported private key"
   - "Successfully created JWT"
   - "Successfully obtained OAuth2 access token"
   - "Sending notifications to X token(s)"
   - "FCM message sent successfully"
   - OR any error messages

**Share the complete log output!**

---

## 🔍 **WHAT TO LOOK FOR**

**If you see:**
- ✅ All success messages → Function is working, check device
- ❌ "Error importing private key" → Key format issue
- ❌ "Error creating JWT" → JWT library issue
- ❌ "OAuth2 token request failed" → Authentication issue
- ❌ "FCM API error" → FCM communication issue

**The logs will now tell us exactly where it's failing!**

---

**Deploy and share the logs!**
