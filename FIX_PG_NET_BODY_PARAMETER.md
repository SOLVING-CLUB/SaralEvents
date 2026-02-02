# Fix: pg_net.http_post Body Parameter

## 🚨 **PROBLEM**

**Error:** `function net.http_post(url => text, headers => jsonb, body => text) does not exist`

**Cause:** `pg_net.http_post` expects `body` to be **JSONB**, not TEXT.

---

## 🔧 **FIX APPLIED**

Reverted the `::text` cast. The body should remain as JSONB:

```sql
body := jsonb_build_object(...)  -- Keep as JSONB, not TEXT
```

`pg_net` will automatically serialize the JSONB to JSON string when sending the HTTP request.

---

## 🚀 **TEST NOW**

The function should work now. Test with:

```sql
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Test After Fix',
  'Testing after reverting body to JSONB',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

---

## 🔍 **IF STILL GETTING JSON PARSING ERROR**

If the edge function still receives invalid JSON, the issue might be:
1. **pg_net version** - Check if you're using the latest version
2. **JSONB serialization** - pg_net should handle this automatically
3. **Edge function parsing** - Make sure edge function uses `await req.json()`

**Share the results!**
