# Verify Notifications Are Working

## ✅ Good News

Your triggers are set up correctly:
- ✅ `new_booking_notification` (INSERT on bookings) - **NEW!**
- ✅ `payment_success_notification` (INSERT and UPDATE on payment_milestones)
- ✅ `booking_status_change_notification` (UPDATE on bookings)

## ⚠️ Issue: 0 Requests in Queue

The fact that there are **0 requests** in `net.http_request_queue` suggests:
1. Triggers aren't firing, OR
2. `send_push_notification` function is failing silently, OR
3. Function doesn't exist or has errors

## 🔍 Diagnostic Steps

### Step 1: Run Test Script

Run this to check everything:

```sql
-- File: apps/user_app/test_notification_triggers.sql
```

This will check:
- ✅ If `send_push_notification` function exists
- ✅ If environment variables are set
- ✅ If users have FCM tokens
- ✅ If trigger functions exist
- ✅ If triggers are enabled

### Step 2: Check Environment Variables

```sql
SELECT 
  current_setting('app.supabase_url', true) as supabase_url,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
    THEN '✅ Set (hidden)'
    ELSE '❌ NOT set'
  END as service_role_key;
```

**If NOT set, run:**
```sql
ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT.supabase.co';
ALTER DATABASE postgres SET app.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY';
```

### Step 3: Test send_push_notification Function

```sql
-- First, get a user ID with active tokens
SELECT u.id, u.email, ft.app_type
FROM auth.users u
JOIN fcm_tokens ft ON ft.user_id = u.id
WHERE ft.is_active = true
LIMIT 1;

-- Then test (replace USER_ID)
SELECT send_push_notification(
  'USER_ID_FROM_ABOVE'::UUID,
  'Test Notification',
  'Testing if notifications work',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

**Expected Result:**
```json
{
  "success": true,
  "request_id": 12345,
  "message": "Notification request queued"
}
```

**If you get an error**, check:
- Environment variables are set
- Edge function is deployed
- Function code is correct

### Step 4: Check Trigger Functions

```sql
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'notify_payment_success',
    'notify_booking_status_change',
    'notify_new_booking',
    'send_push_notification'
  );
```

All 4 functions should exist.

### Step 5: Verify Triggers Are Enabled

```sql
SELECT 
  t.trigger_name,
  pt.tgenabled as status
FROM information_schema.triggers t
JOIN pg_trigger pt ON pt.tgname = t.trigger_name
WHERE t.trigger_schema = 'public'
  AND t.trigger_name IN (
    'payment_success_notification',
    'booking_status_change_notification',
    'new_booking_notification'
  );
```

All should show `O` (enabled).

## 🧪 Test Scenarios

### Test 1: Create New Booking
1. Create a booking from user app
2. Check if vendor gets "New Order Received" notification
3. Check `net.http_request_queue` for new requests

### Test 2: Complete Payment
1. Complete a payment from user app
2. Check if both apps get payment notifications
3. Check `net.http_request_queue` for new requests

### Test 3: Manual Function Test
1. Run the test query from Step 3
2. Check if request appears in queue
3. Check edge function logs

## 🐛 Common Issues

### Issue: Function Returns Error
**Check:**
- Environment variables are set correctly
- Supabase URL is correct (no trailing slash)
- Service role key is correct

### Issue: Function Returns Success But No Requests
**Check:**
- pg_net extension is enabled: `SELECT * FROM pg_extension WHERE extname = 'pg_net';`
- Edge function is deployed: `supabase functions list`
- Check Supabase Dashboard > Logs

### Issue: Triggers Don't Fire
**Check:**
- Triggers are enabled (Step 5)
- Trigger functions exist (Step 4)
- Data actually changed (check bookings/payment_milestones tables)

## 📊 Next Steps

1. **Run test script** to identify the issue
2. **Set environment variables** if missing
3. **Test function manually** to verify it works
4. **Check edge function** is deployed
5. **Test with real data** (create booking, complete payment)

## 🔗 Related Files

- `test_notification_triggers.sql` - Comprehensive test script
- `fix_payment_order_notifications.sql` - Fix script (already run)
- `diagnose_payment_order_notifications.sql` - Diagnostic script
