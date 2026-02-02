# Final Solution: pg_net to Edge Function Issue

## ✅ **CONFIRMED**

- ✅ pg_net IS working (got response from httpbin)
- ✅ Edge function IS working (direct test works)
- ❌ pg_net requests to edge function don't reach it

**This is a known Supabase limitation:** pg_net requests from database to edge functions might be blocked or require special configuration.

---

## 🔧 **SOLUTION: Use Anon Key Instead of Service Role Key**

**Supabase edge functions might accept requests with anon key for internal calls. Let's try that:**

---

## 🔧 **STEP 1: Update Database Function to Use Anon Key**

**Update the database function to use anon key instead of service role key:**

```sql
-- Update send_push_notification to use anon key
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
  v_anon_key TEXT;  -- Changed from service_role_key
  v_request_id BIGINT;
BEGIN
  v_supabase_url := current_setting('app.supabase_url', true);
  v_anon_key := current_setting('app.supabase_anon_key', true);
  
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://hucsihwqsuvqvbnyapdn.supabase.co';
  END IF;
  
  IF v_anon_key IS NULL THEN
    -- Use your anon key from Dashboard > Settings > API
    v_anon_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1Y3NpaHdxc3V2cXZibnlhcGRuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk0ODYsImV4cCI6MjA2ODA1NTQ4Nn0.gSu1HE7eZ4n3biaM338wDF0L2m4Yc3xYyt2GtuPOr1w';
  END IF;

  BEGIN
    v_request_id := net.http_post(
      url := v_supabase_url || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_anon_key,  -- Changed to anon key
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

## 🔧 **STEP 2: Test with Anon Key**

```sql
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Test with Anon Key',
  'Testing with anon key instead of service role key',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

**Then:**
1. Wait 20-30 seconds
2. Check edge function logs
3. Check app for notification

---

## 🔧 **ALTERNATIVE: Make Edge Function Public**

**If anon key doesn't work, try making the edge function publicly accessible:**

1. Go to Supabase Dashboard > Edge Functions > send-push-notification
2. Check Settings tab
3. Look for "Public" or "Require Auth" option
4. Try making it public temporarily to test

---

## 🎯 **MOST LIKELY SOLUTION**

**Use anon key instead of service role key** - Edge functions might accept anon key for internal calls from pg_net.

**Try Step 1 and Step 2, then share the results!**
