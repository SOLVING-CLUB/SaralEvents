# Next Steps: Test Notifications

## ✅ Current Status

All checks passed:
- ✅ Triggers are enabled
- ✅ `send_push_notification` function exists
- ✅ pg_net extension enabled
- ✅ FCM tokens registered
- ✅ User available for testing

## 🧪 Test the Function

### Step 1: Test Manually

Run this SQL query:

```sql
-- File: apps/user_app/TEST_NOTIFICATION_NOW.sql
```

Or run directly:

```sql
SELECT send_push_notification(
  'ad73265c-4877-4a94-8394-5c455cc2a012'::UUID,
  'Test Notification',
  'This is a test notification. If you receive this, notifications are working!',
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

### Step 2: Check Results

#### If Success (success: true):
1. **Check your device** - You should receive a notification
2. **Check edge function logs:**
   ```bash
   supabase functions logs send-push-notification --tail
   ```
3. **Check request queue:**
   ```sql
   SELECT * FROM net.http_request_queue ORDER BY id DESC LIMIT 5;
   ```

#### If Error:
1. **Check the error message** - It will tell you what's wrong
2. **Common errors:**
   - `404 Not Found` → Edge function not deployed
   - `401 Unauthorized` → Service role key incorrect
   - `500 Internal Server Error` → Check edge function logs

### Step 3: Test Real Scenarios

Once manual test works:

1. **Test New Order:**
   - Create a booking from user app
   - Vendor should get "New Order Received" notification

2. **Test Payment:**
   - Complete a payment from user app
   - Both apps should get payment notifications

## 🔧 If Manual Test Fails

### Check Edge Function

```bash
# List functions
supabase functions list

# Check if send-push-notification exists
# If not, deploy it:
supabase functions deploy send-push-notification
```

### Check FCM Secret

```bash
# List secrets
supabase secrets list

# Check if FCM_SERVICE_ACCOUNT_BASE64 is set
# If not, set it:
supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="<base64_encoded_json>"
```

### Check Edge Function Logs

```bash
supabase functions logs send-push-notification --tail 50
```

Look for:
- `FCM service account not configured` → Set FCM secret
- `No active tokens found` → User needs to login to app
- `FCM API error` → Check FCM Service Account JSON

## 📊 Verification Checklist

After testing:

- [ ] Manual test returns `success: true`
- [ ] Notification appears on device
- [ ] Edge function logs show successful request
- [ ] Request appears in `net.http_request_queue`
- [ ] New booking triggers vendor notification
- [ ] Payment triggers both app notifications

## 🎯 Expected Flow

1. **User creates booking** → `new_booking_notification` trigger fires → Vendor gets notification
2. **User completes payment** → `payment_success_notification` trigger fires → Both apps get notifications
3. **Booking status changes** → `booking_status_change_notification` trigger fires → User gets notification

## 🐛 Troubleshooting

### No notification received:
1. Check device notification permissions
2. Check app is running or in background
3. Check FCM token is active: `SELECT * FROM fcm_tokens WHERE user_id = '...' AND is_active = true;`
4. Check edge function logs for errors

### Function returns error:
1. Check error message
2. Verify edge function is deployed
3. Verify FCM secret is set
4. Check environment variables (though function has fallbacks)

### Triggers don't fire:
1. Verify triggers are enabled (already checked ✅)
2. Verify data actually changed (check bookings/payment_milestones tables)
3. Check PostgreSQL logs for trigger errors

## 📝 Files Reference

- `TEST_NOTIFICATION_NOW.sql` - Quick test query
- `FINAL_NOTIFICATION_CHECK.sql` - Comprehensive diagnostic
- `fix_payment_order_notifications.sql` - Fix script (already run ✅)
