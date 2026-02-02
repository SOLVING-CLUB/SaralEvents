# Quick Configuration Check - Step by Step

## 🎯 **VERIFICATION CHECKLIST**

Run these checks in order. Share the results with me, and I'll guide you through any fixes needed.

---

## ✅ **STEP 1: Check Supabase Secrets**

**Run this command:**
```bash
npx supabase secrets list
```

**Expected Output:**
```
FCM_SERVICE_ACCOUNT_BASE64
```

**What to share:**
- ✅ If you see `FCM_SERVICE_ACCOUNT_BASE64` → Write "✅ FCM secret exists"
- ❌ If you DON'T see it → Write "❌ FCM secret missing"

---

## ✅ **STEP 2: Verify Database Function Service Role Key**

**Run this query in Supabase SQL Editor:**
```sql
-- Check the service role key in send_push_notification function
SELECT 
  CASE 
    WHEN routine_definition LIKE '%sb_secret_QhWTQOnAO-SCeCWmWEQF6A_AAdf38pq%' THEN '✅ Key found in function'
    WHEN routine_definition LIKE '%sb_secret_%' THEN '⚠️ Different key found'
    ELSE '❌ No service key found'
  END as key_status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'send_push_notification';
```

**Then verify it matches your actual service role key:**

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Settings** > **API**
4. Scroll to **Secret keys** section
5. Click the **eye icon** next to `service_role` key
6. Copy the key (starts with `sb_secret_...`)

**What to share:**
- ✅ If the key in the function matches your Supabase service role key → Write "✅ Service key matches"
- ❌ If it doesn't match → Write "❌ Service key mismatch" and share the first 20 characters of your actual key

---

## ✅ **STEP 3: Verify Firebase Service Account**

**Check 1: Service Account Exists**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: **saralevents-6fe20**
3. Go to **Project Settings** (gear icon) > **Service Accounts** tab
4. Look for service account: `firebase-adminsdk-fbsvc@saralevents-6fe20.iam.gserviceaccount.com`

**What to share:**
- ✅ If it exists → Write "✅ Service account exists"
- ❌ If it doesn't exist → Write "❌ Service account missing"

**Check 2: Service Account Permissions**

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select project: **saralevents-6fe20**
3. Go to **IAM & Admin** > **Service Accounts**
4. Find: `firebase-adminsdk-fbsvc@saralevents-6fe20.iam.gserviceaccount.com`
5. Click on it
6. Check if it has **Firebase Cloud Messaging API** enabled

**What to share:**
- ✅ If FCM API is enabled → Write "✅ FCM API enabled"
- ❌ If not enabled → Write "❌ FCM API not enabled"

---

## ✅ **STEP 4: Test Edge Function**

**Run this query in Supabase SQL Editor:**
```sql
-- Replace USER_ID with an actual user ID from your auth.users table
SELECT send_push_notification(
  (SELECT id FROM auth.users LIMIT 1)::UUID,
  'Configuration Test',
  'Testing all configuration settings',
  '{"type":"test","config_check":true}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

**Then check:**
1. Go to Supabase Dashboard > **Edge Functions** > **send-push-notification**
2. Check the **Logs** tab
3. Look for recent executions

**What to share:**
- ✅ If you see successful execution → Write "✅ Edge function works"
- ❌ If you see errors → Share the error message

---

## 📋 **QUICK SUMMARY FORMAT**

Copy and fill this out:

```
STEP 1 - Supabase Secrets:
[ ] FCM_SERVICE_ACCOUNT_BASE64 exists / missing

STEP 2 - Database Function:
[ ] Service key matches / mismatch
[ ] My actual key starts with: sb_secret_...

STEP 3 - Firebase Service Account:
[ ] Service account exists / missing
[ ] FCM API enabled / not enabled

STEP 4 - Edge Function Test:
[ ] Works / Error: [paste error if any]
```

---

## 🔧 **IF ANYTHING IS MISSING**

I'll provide step-by-step fixes based on your results. The most common issues are:

1. **FCM_SERVICE_ACCOUNT_BASE64 missing** → Follow `apps/user_app/HOW_TO_CREATE_FCM_BASE64.md`
2. **Service role key mismatch** → Update database function
3. **Service account missing** → Create in Firebase Console
4. **FCM API not enabled** → Enable in Google Cloud Console

---

**Share your results and I'll guide you through any fixes!**
