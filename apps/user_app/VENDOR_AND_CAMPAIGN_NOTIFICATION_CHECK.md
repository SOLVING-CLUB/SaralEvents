# Vendor App & Campaign Notification Verification

## ✅ What to Check

### 1. Vendor App Notifications

**Status:** Should work with the updated edge function (Firebase Admin SDK compatible)

**How to Test:**
1. **Check vendor tokens:**
   ```sql
   -- Run: apps/user_app/VERIFY_VENDOR_AND_CAMPAIGN_NOTIFICATIONS.sql
   -- Or check directly:
   SELECT * FROM fcm_tokens 
   WHERE app_type = 'vendor_app' 
   AND is_active = true;
   ```

2. **Test vendor notification:**
   ```sql
   SELECT send_push_notification(
     (SELECT user_id FROM vendor_profiles LIMIT 1)::UUID,
     'Vendor Test',
     'Testing vendor app notification',
     '{"type":"test"}'::JSONB,
     NULL,
     ARRAY['vendor_app']::TEXT[]
   );
   ```

3. **Check Dashboard logs:**
   - Go to: Supabase Dashboard > Edge Functions > send-push-notification > Logs
   - Look for: `Fetched X tokens for user... with appTypes: vendor_app`

### 2. Campaign Notifications

**Status:** Should work - campaigns use the same edge function

**How Campaigns Work:**
- **All Users** → `appTypes: ['user_app']`
- **All Vendors** → `appTypes: ['vendor_app']`
- **Specific Users** → Determines app type per user

**How to Test:**
1. **Go to Company Web Dashboard:**
   - Navigate to: Campaigns page
   - Create a new campaign
   - Select target audience:
     - "All Users" → Should send to user_app only
     - "All Vendors" → Should send to vendor_app only
   - Send immediately

2. **Check campaign status:**
   ```sql
   SELECT * FROM notification_campaigns 
   ORDER BY created_at DESC 
   LIMIT 5;
   ```

3. **Check Dashboard logs:**
   - Look for campaign notification requests
   - Verify `appTypes` is set correctly

## 🔍 Verification Checklist

### Vendor App Notifications
- ✅ Vendor tokens exist in database
- ✅ Tokens are active
- ✅ Edge function finds vendor tokens (check logs)
- ✅ Notifications sent successfully (check logs)
- ✅ Vendor app receives notifications

### Campaign Notifications
- ✅ Campaign created in database
- ✅ Campaign status is "sent" (not "failed")
- ✅ `sent_count` > 0
- ✅ Edge function processes campaign requests (check logs)
- ✅ Correct `appTypes` used:
  - All Users → `['user_app']`
  - All Vendors → `['vendor_app']`
- ✅ Users/vendors receive notifications in correct apps

## 🎯 Expected Results

### Vendor App Notification Test
1. Function returns: `{"success":true,"request_id":X}`
2. Dashboard logs show: `Fetched 1 tokens for user... with appTypes: vendor_app`
3. Vendor app receives notification ✅

### Campaign Notification Test
1. Campaign status: `sent`
2. `sent_count` > 0
3. Dashboard logs show multiple requests with correct `appTypes`
4. Users/vendors receive notifications in correct apps ✅

## 📊 Diagnostic Queries

Run this comprehensive check:

```sql
-- File: apps/user_app/VERIFY_VENDOR_AND_CAMPAIGN_NOTIFICATIONS.sql
```

This will show:
- Vendor token status
- Campaign notification history
- Test notifications for both apps
- Recipient counts

## 🔧 Common Issues

### Issue 1: No Vendor Tokens
**Symptom:** `No active tokens found` in logs

**Fix:**
1. Vendor needs to login to vendor app
2. Wait for token registration
3. Verify token exists: `SELECT * FROM fcm_tokens WHERE app_type = 'vendor_app'`

### Issue 2: Campaign Not Sending
**Symptom:** Campaign status is "failed" or `sent_count` is 0

**Fix:**
1. Check Dashboard logs for errors
2. Verify campaign target audience is set correctly
3. Check if users/vendors have active tokens

### Issue 3: Notifications Going to Wrong App
**Symptom:** User receives vendor notification or vice versa

**Fix:**
1. Verify `appTypes` parameter in campaign code
2. Check edge function logs to see which `appTypes` were used
3. Verify tokens have correct `app_type` in database

## 📝 Next Steps

1. **Run diagnostic script:** `VERIFY_VENDOR_AND_CAMPAIGN_NOTIFICATIONS.sql`
2. **Test vendor notification:** Use the test query above
3. **Test campaign:** Create a campaign from Company Web Dashboard
4. **Check Dashboard logs:** Verify both are working
5. **Share results:** Let me know if you find any issues!

## 🎉 Status

- ✅ Edge function updated (Firebase Admin SDK compatible)
- ✅ Edge function deployed
- ✅ Campaign code uses `appTypes` correctly
- ⏳ **Ready to test** - Run the diagnostic and test queries

Both vendor app and campaign notifications should work with the updated edge function!
