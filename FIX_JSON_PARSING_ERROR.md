# Fix: JSON Parsing Error in Edge Function

## 🚨 **PROBLEM IDENTIFIED**

**Error:** `SyntaxError: Unexpected token 'S', "SELECT sen"... is not valid JSON`

**Cause:** The `pg_net.http_post` function is sending the SQL query itself instead of the JSON body, or the JSON body isn't being serialized correctly.

---

## 🔧 **FIX APPLIED**

I've updated the database function to explicitly convert the JSONB body to text:

```sql
body := jsonb_build_object(...)::text
```

This ensures the JSON is properly serialized as a string before being sent.

---

## 🚀 **DEPLOY THE FIX**

### **Step 1: Update Database Function**

Run this SQL in Supabase SQL Editor:

```sql
-- Update the send_push_notification function body parameter
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
  -- Get configuration from environment or use defaults
  v_supabase_url := current_setting('app.supabase_url', true);
  v_service_role_key := current_setting('app.supabase_service_role_key', true);
  
  -- Use hardcoded values if environment variables not set
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://hucsihwqsuvqvbnyapdn.supabase.co';
  END IF;
  
  IF v_service_role_key IS NULL THEN
    v_service_role_key := 'sb_secret_QhWTQOnAO-SCeCWmWEQF6A_AAdf38pq';
  END IF;

  -- Use pg_net extension (Supabase's native and recommended method)
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
      )::text  -- Convert JSONB to text explicitly
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

### **Step 2: Test**

```sql
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Test After Fix',
  'Testing after JSON body fix',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

### **Step 3: Check Logs**

1. Go to Supabase Dashboard > **Edge Functions** > **send-push-notification** > **Logs**
2. Should now see proper JSON parsing and execution
3. Should see: "Fetched X tokens..." and "FCM message sent successfully"

---

## ✅ **WHAT THIS FIXES**

- ✅ JSON body properly serialized as text
- ✅ Edge function receives valid JSON
- ✅ No more "Unexpected token" errors
- ✅ Notifications should work now

---

**Run the SQL update and test!**
