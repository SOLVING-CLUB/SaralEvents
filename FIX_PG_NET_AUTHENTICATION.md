# Fix: pg_net Not Reaching Edge Function

## 🔍 **PROBLEM ANALYSIS**

- ✅ Direct test works (edge function is fine)
- ✅ Database function returns success (pg_net queued request)
- ❌ No logs in edge function (request not reaching it)
- ❌ No notification (request not processed)

**This means:** pg_net request is being sent but not reaching/executing the edge function.

---

## 🔧 **MOST LIKELY ISSUE: Authentication**

Edge functions require authentication. When called via pg_net, the Authorization header must be correct.

---

## 🔧 **STEP 1: Verify Service Role Key**

**Check if the service role key in the database function matches your actual key:**

1. Go to Supabase Dashboard > **Settings** > **API** > **Secret keys**
2. Click the **eye icon** next to `service_role` key
3. Copy the full key (starts with `sb_secret_...`)

**Does it match:** `sb_secret_QhWTQOnAO-SCeCWmWEQF6A_AAdf38pq`?

**If NO:**
- Update the database function with the correct key
- See Step 2 below

**If YES:**
- The key is correct, proceed to Step 3

---

## 🔧 **STEP 2: Update Service Role Key in Database Function**

**If the key doesn't match, update it:**

```sql
-- Update the service role key in send_push_notification function
-- Replace 'YOUR_ACTUAL_SERVICE_ROLE_KEY' with the key from Dashboard

CREATE OR REPLACE FUNCTION send_push_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT NULL,
  p_image_url TEXT DEFAULT NULL,
  p_app_types TEXT[] DEFAULT ARRAY['user_app', 'vendor_app']
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_role_key TEXT;
  v_request_id BIGINT;
BEGIN
  v_supabase_url := current_setting('app.supabase_url', true);
  v_service_role_key := current_setting('app.supabase_service_role_key', true);
  
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://hucsihwqsuvqvbnyapdn.supabase.co';
  END IF;
  
  IF v_service_role_key IS NULL THEN
    -- UPDATE THIS WITH YOUR ACTUAL SERVICE ROLE KEY
    v_service_role_key := 'YOUR_ACTUAL_SERVICE_ROLE_KEY_HERE';
  END IF;

  BEGIN
    v_request_id := net.http_post(
      url := v_supabase_url || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_service_role_key,
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'userId', p_user_id,
        'title', p_title,
        'body', p_body,
        'data', p_data,
        'imageUrl', COALESCE(p_image_url, ''),
        'appTypes', p_app_types
      )
    );
    
    RETURN jsonb_build_object(
      'success', true, 
      'request_id', v_request_id,
      'message', 'Notification request queued'
    );
  EXCEPTION
    WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
      );
  END;
END;
$$;
```

---

## 🔧 **STEP 3: Test After Update**

**After updating the key (if needed), test:**

```sql
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Test After Key Update',
  'Testing with correct service role key',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

**Then:**
1. Wait 10-20 seconds
2. Check edge function logs
3. Check app for notification

---

## 🔍 **ALTERNATIVE: Check Edge Function Logs for Auth Errors**

**Even if there are no execution logs, check for:**
- Authentication errors
- 401 Unauthorized responses
- Rejected requests

**Go to:** Supabase Dashboard > Edge Functions > send-push-notification > Logs

**Look for any errors around the time you ran the database function.**

---

## ✅ **WHAT TO DO**

1. **Verify service role key** (Step 1)
2. **Update if wrong** (Step 2)
3. **Test again** (Step 3)
4. **Check logs** after waiting 10-20 seconds

**Share:**
- Does the service role key match?
- Any errors in edge function logs?
- Results after updating (if needed)
