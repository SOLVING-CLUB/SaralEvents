# Fix: Edge Function Not Executing (Empty Logs)

## 🚨 **PROBLEM IDENTIFIED**

**Symptoms:**
- ✅ Database function returns success
- ✅ FCM tokens exist
- ✅ SHA-1 fingerprints added
- ✅ FCM API enabled
- ❌ **Edge function logs are EMPTY** ← Edge function not executing!

**Root Cause:** Edge function is either:
1. Not deployed
2. Not receiving requests from pg_net
3. Failing silently before logging

---

## 🔧 **STEP 1: Check if Edge Function is Deployed**

**Go to Supabase Dashboard:**
1. Navigate to **Edge Functions**
2. Look for **send-push-notification** in the list

**If it's NOT there:**
- Edge function needs to be deployed
- See deployment steps below

**If it IS there:**
- Check **Status** (should be "Active")
- Check **Last Deployed** date
- Proceed to Step 2

---

## 🔧 **STEP 2: Test Edge Function Directly (CRITICAL!)**

**This will tell us if the edge function works at all:**

1. Go to Supabase Dashboard > **Edge Functions** > **send-push-notification**
2. Click **Invoke** button (or "Test" button)
3. Use this payload:

```json
{
  "userId": "ad73265c-4877-4a94-8394-5c455cc2a012",
  "title": "Direct Edge Function Test",
  "body": "Testing edge function directly from Dashboard",
  "appTypes": ["user_app"],
  "data": {
    "type": "test",
    "direct": true
  }
}
```

4. Click **Invoke** or **Run**
5. **Check the response:**
   - ✅ **Status 200** → Edge function works!
   - ❌ **Status 404** → Edge function not deployed
   - ❌ **Status 500** → Edge function error (check response body)
6. **Check Logs tab** - should now show logs

**Share the response you get!**

---

## 🔧 **STEP 3: Check pg_net Request Queue**

**This shows if requests are reaching the edge function:**

```sql
-- Check pg_net request queue for recent requests
SELECT 
  id,
  created_at,
  method,
  url,
  status_code,
  error_msg,
  LEFT(request_headers::TEXT, 100) as headers_preview,
  CASE 
    WHEN status_code = 200 THEN '✅ Success'
    WHEN status_code = 404 THEN '❌ Function not found'
    WHEN status_code = 500 THEN '❌ Function error'
    WHEN status_code IS NULL THEN '⚠️ Pending'
    ELSE '❌ Error: ' || status_code::TEXT
  END as status
FROM net.http_request_queue
WHERE created_at >= NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 10;
```

**What to look for:**
- ✅ **status_code = 200** → Request succeeded (but why no logs?)
- ❌ **status_code = 404** → Edge function not found (needs deployment)
- ❌ **status_code = 500** → Edge function error (check error_msg)
- ⚠️ **status_code IS NULL** → Request still pending

**Share the results!**

---

## 🔧 **STEP 4: Verify Edge Function URL**

**Check if the URL in database function matches your project:**

The database function calls:
```
https://hucsihwqsuvqvbnyapdn.supabase.co/functions/v1/send-push-notification
```

**Verify:**
1. Go to Supabase Dashboard > **Settings** > **API**
2. Check **Project URL** - should be: `https://hucsihwqsuvqvbnyapdn.supabase.co`
3. Verify edge function path: `/functions/v1/send-push-notification`

**If URL is wrong:**
- Update database function
- See `apps/user_app/automated_notification_triggers.sql` line 78

---

## 🔧 **STEP 5: Deploy Edge Function (If Not Deployed)**

**If edge function doesn't exist or needs redeployment:**

### **Option A: Using Supabase CLI**

```bash
# 1. Navigate to project root
cd C:\Users\karth\OneDrive\Desktop\SOLVING_CLUB\SaralEvents

# 2. Link to your project (if not already linked)
npx supabase link --project-ref hucsihwqsuvqvbnyapdn

# 3. Navigate to user app
cd apps/user_app

# 4. Deploy the function
npx supabase functions deploy send-push-notification
```

**Expected Output:**
```
Deploying function send-push-notification...
Function deployed successfully
```

### **Option B: Using Supabase Dashboard**

1. Go to Supabase Dashboard > **Edge Functions**
2. Click **"Create a new function"**
3. Name: `send-push-notification`
4. Copy code from: `apps/user_app/supabase/functions/send-push-notification/index.ts`
5. Paste into editor
6. Click **Deploy**

---

## 🔧 **STEP 6: Verify FCM Secret is Accessible**

**Check if secret is set for edge functions:**

1. Go to Supabase Dashboard > **Edge Functions** > **send-push-notification**
2. Click **Settings** tab
3. Check **Secrets** section
4. Verify `FCM_SERVICE_ACCOUNT_BASE64` is listed

**If not listed:**
- The secret might be set globally but not accessible to edge functions
- Re-set it:
  ```bash
  npx supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="YOUR_BASE64_VALUE"
  ```

---

## 🎯 **MOST LIKELY ISSUE**

Based on empty logs, the edge function is **probably not deployed** or **not receiving requests**.

**Most likely causes:**
1. **Edge function not deployed** (60%)
   - Function doesn't exist in Supabase
   - Needs deployment

2. **pg_net request failing** (30%)
   - URL mismatch
   - Authentication issue
   - Network issue

3. **Edge function failing silently** (10%)
   - Error before logging
   - Check pg_net request queue

---

## 📋 **IMMEDIATE ACTION PLAN**

**Do these in order:**

1. ✅ **Test Edge Function Directly** (Step 2)
   - Use Dashboard > Invoke
   - Share the response

2. ✅ **Check pg_net Request Queue** (Step 3)
   - Run the SQL query
   - Share the results

3. ✅ **Verify Edge Function Exists** (Step 1)
   - Check Dashboard
   - Share if it exists or not

4. ✅ **If not deployed, deploy it** (Step 5)
   - Use CLI or Dashboard
   - Verify deployment

---

## 🔍 **SHARE THESE RESULTS**

1. **Edge Function Direct Test Response** (from Step 2)
   - Status code
   - Response body
   - Any error messages

2. **pg_net Request Queue Results** (from Step 3)
   - status_code values
   - error_msg if any
   - URL being called

3. **Edge Function Deployment Status** (from Step 1)
   - Does it exist?
   - What's the status?

**This will tell us exactly what's wrong and how to fix it!**
