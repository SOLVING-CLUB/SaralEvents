# Test Edge Function via Supabase Dashboard

## 🔧 **STEP 1: Test Edge Function Using POST Method**

Since you see "Test" option with GET/POST methods:

1. Go to Supabase Dashboard > **Edge Functions** > **send-push-notification**
2. Click **Test** button
3. Select **POST** method
4. In the **Body** field, paste this JSON:

```json
{
  "userId": "ad73265c-4877-4a94-8394-5c455cc2a012",
  "title": "Direct Test from Dashboard",
  "body": "Testing edge function via Dashboard POST",
  "appTypes": ["user_app"],
  "data": {
    "type": "test",
    "source": "dashboard"
  }
}
```

5. Click **Run** or **Send** button
6. **Check:**
   - **Response** section - shows status code and response body
   - **Logs** tab - should show execution logs

**Share:**
- Response status code (200, 404, 500?)
- Response body (what does it say?)
- Any error messages

---

## 🔧 **STEP 2: Check pg_net Request Queue (Fixed Query)**

**Run this corrected query:**

```sql
-- Check pg_net request queue (checking available columns first)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'net'
  AND table_name = 'http_request_queue'
ORDER BY ordinal_position;
```

**This will show us the correct column names.**

**Then run this (after we know the columns):**

```sql
-- Check recent requests (using correct column names)
SELECT 
  id,
  url,
  status_code,
  error_msg
FROM net.http_request_queue
ORDER BY id DESC
LIMIT 5;
```

**Share the results!**

---

## 🔧 **STEP 3: Alternative - Check Edge Function Logs After Test**

**After running the POST test (Step 1):**

1. Go to **Logs** tab in the edge function
2. Look for the most recent log entry
3. **Share:**
   - What the log says
   - Any error messages
   - Success/failure status

---

## 🎯 **WHAT TO SHARE**

1. **POST Test Response** (from Step 1)
   - Status code
   - Response body
   - Any errors

2. **Column Names** (from Step 2 first query)
   - What columns exist in net.http_request_queue

3. **Logs** (from Step 3)
   - What the logs show after testing

**This will tell us exactly what's happening!**
