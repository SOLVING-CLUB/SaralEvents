# Test Edge Function Directly

## 🎯 Purpose

Test the edge function directly (bypassing the database function) to see if it's working correctly.

## Method 1: Using Supabase Dashboard (Easiest)

1. **Go to:** Supabase Dashboard > Edge Functions > send-push-notification
2. **Click:** "Invoke" button
3. **Use this payload:**
   ```json
   {
     "userId": "ad73265c-4877-4a94-8394-5c455cc2a012",
     "title": "Direct Edge Function Test",
     "body": "Testing edge function directly from Dashboard",
     "appTypes": ["user_app"],
     "data": {
       "type": "test"
     }
   }
   ```
4. **Click:** "Invoke"
5. **Check:**
   - Response (should show success/failure)
   - Logs tab (will show detailed execution)

## Method 2: Using Supabase CLI

Run this command:

```bash
cd apps/user_app
npx supabase functions invoke send-push-notification --body '{"userId":"ad73265c-4877-4a94-8394-5c455cc2a012","title":"CLI Test","body":"Testing from CLI","appTypes":["user_app"],"data":{"type":"test"}}'
```

## Method 3: Using curl (if you have the anon key)

```bash
curl -X POST \
  'https://hucsihwqsuvqvbnyapdn.supabase.co/functions/v1/send-push-notification' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "ad73265c-4877-4a94-8394-5c455cc2a012",
    "title": "Curl Test",
    "body": "Testing from curl",
    "appTypes": ["user_app"],
    "data": {"type": "test"}
  }'
```

## 📊 What to Look For

### Success Response:
```json
{
  "success": true,
  "sent": 1,
  "failed": 0
}
```

### Error Responses:

**No tokens found:**
```json
{
  "message": "No active tokens found",
  "success": false
}
```

**FCM API error:**
```json
{
  "error": "FCM API error: ...",
  "success": false
}
```

**Service account error:**
```json
{
  "error": "FCM service account not configured...",
  "success": false
}
```

## 🔍 Check Logs

After invoking, check:
- **Dashboard > Edge Functions > send-push-notification > Logs**
- Look for:
  - `Fetched X tokens for user...`
  - `Sent notification successfully`
  - Error messages

## 🎯 Expected Flow

1. Edge function receives request ✅
2. Fetches tokens from database ✅
3. Gets FCM access token ✅
4. Sends to FCM API ✅
5. Returns success ✅
6. Device receives notification ✅

## 📝 Next Steps

1. **Test using Method 1 (Dashboard)** - easiest
2. **Check the response** - tells you if it worked
3. **Check the logs** - shows detailed execution
4. **Share the results** - I can help fix any errors
