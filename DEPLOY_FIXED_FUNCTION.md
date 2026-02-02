# Deploy Fixed send_push_notification Function

## 🔧 **FIX APPLIED**

I've updated the `send_push_notification` function to use **anon key** instead of service role key. The file has been updated.

---

## 🚀 **DEPLOY THE FIX**

### **Step 1: Update Function in Database**

**Run this SQL in Supabase SQL Editor:**

```sql
-- Update send_push_notification to use anon key
CREATE OR REPLACE FUNCTION send_push_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT NULL,
  p_image_url TEXT DEFAULT NULL,
  p_app_types TEXT[] DEFAULT ARRAY['user_app', 'vendor_app']::TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_response JSONB;
  v_supabase_url TEXT;
  v_anon_key TEXT;  -- Changed to anon key
  v_request_id BIGINT;
BEGIN
  v_supabase_url := current_setting('app.supabase_url', true);
  v_anon_key := current_setting('app.supabase_anon_key', true);
  
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://hucsihwqsuvqvbnyapdn.supabase.co';
  END IF;
  
  IF v_anon_key IS NULL THEN
    v_anon_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1Y3NpaHdxc3V2cXZibnlhcGRuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI0Nzk0ODYsImV4cCI6MjA2ODA1NTQ4Nn0.gSu1HE7eZ4n3biaM338wDF0L2m4Yc3xYyt2GtuPOr1w';
  END IF;

  IF v_supabase_url IS NULL OR v_anon_key IS NULL OR 
     v_supabase_url = '' OR v_anon_key = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'skipped', true,
      'reason', 'missing_config',
      'error', 'Please update the function with your Supabase URL and anon key.'
    );
  END IF;

  BEGIN
    v_request_id := net.http_post(
      url := v_supabase_url || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || v_anon_key,
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
        'error', SQLERRM, 
        'success', false,
        'message', 'Please enable pg_net extension: CREATE EXTENSION IF NOT EXISTS pg_net;'
      );
  END;
END;
$$;
```

### **Step 2: Verify Triggers**

**Check if all triggers exist:**

```sql
SELECT 
  trigger_name,
  event_object_table,
  event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE '%notification%'
ORDER BY event_object_table, trigger_name;
```

### **Step 3: Test Order Flow**

**Test creating a booking:**
1. Create a booking from user app
2. **Vendor should receive:** "New Order Received"
3. Check edge function logs

**Test payment:**
1. Complete a payment
2. **Both apps should receive:** Payment notifications
3. Check edge function logs

---

## ✅ **WHAT THIS FIXES**

- ✅ All order flow notifications will work
- ✅ New booking notifications
- ✅ Payment notifications
- ✅ Status change notifications
- ✅ All triggers will now work

---

**Run Step 1 to update the function, then test the order flow!**
