# Fix: pg_net Not Reaching Edge Function

## ✅ **GOOD NEWS**

**Direct test works!** The edge function is:
- ✅ Deployed correctly
- ✅ Sending notifications successfully
- ✅ Processing requests properly

**The issue:** pg_net requests from the database function aren't reaching the edge function.

---

## 🔧 **STEP 1: Check pg_net Request Details**

**Check what pg_net is actually sending:**

```sql
-- Check request_id 23 details
SELECT 
  id,
  url,
  method,
  headers,
  body
FROM net.http_request_queue
WHERE id = 23;
```

**This will show:**
- The URL being called
- The headers (including Authorization)
- The body being sent

**Share the results!**

---

## 🔧 **STEP 2: Check if Request is Pending**

**pg_net is async, so the request might still be processing:**

```sql
-- Check if there are any pending requests
SELECT 
  id,
  url,
  method,
  created_at
FROM net.http_request_queue
WHERE id >= 20
ORDER BY id DESC
LIMIT 10;
```

**Share the results!**

---

## 🔍 **POSSIBLE ISSUES**

1. **Authorization header** - Service role key might be wrong in the database function
2. **URL format** - The URL might not be correct
3. **pg_net async delay** - Request might still be processing
4. **Edge function authentication** - Edge function might be rejecting the request

---

## 🔧 **QUICK FIX: Verify Service Role Key**

**Check if the service role key in the database function matches your actual key:**

1. Go to Supabase Dashboard > **Settings** > **API** > **Secret keys**
2. Click the eye icon next to `service_role` key
3. Verify it matches: `sb_secret_QhWTQOnAO-SCeCWmWEQF6A_AAdf38pq`

**If it doesn't match, update the database function with the correct key.**

---

**Run Step 1 and share the results - this will show us exactly what pg_net is sending!**
