# Vendor App Notification Test

## 🧪 **TEST STEPS**

### **Step 1: Run Test SQL**

**Run:** `TEST_VENDOR_NOTIFICATION_SPECIFIC.sql`

**This will:**
1. Check FCM tokens for both vendors
2. Send test notification to Sun City Farmhouse vendor
3. Send test notification to other vendor
4. Update booking status to trigger vendor notification
5. Check pg_net queue for notification requests
6. Verify booking was updated

---

## 📋 **WHAT TO CHECK**

### **1. Vendor FCM Tokens Check**
- ✅ **If vendor has active token** → Notification should work
- ❌ **If vendor has no active token** → Vendor needs to register FCM token in app

### **2. Test Notifications**
- Should return: `{"success":true,"request_id":X}` for each test
- Check pg_net queue for notification requests
- **Check vendor app** - Should receive test notifications

### **3. Booking Status Change Notification**
- Booking updated from 'confirmed' to 'completed'
- **Vendor should receive:** "Order Completed"
- Check vendor app for notification

---

## 🔍 **IF VENDOR DOESN'T RECEIVE NOTIFICATIONS**

### **Check 1: FCM Token**
```sql
SELECT 
  user_id,
  app_type,
  is_active,
  created_at
FROM fcm_tokens
WHERE user_id = '777e7e48-388c-420e-89b9-85693197e0b7'
  AND app_type = 'vendor_app'
  AND is_active = true;
```

**If no token:**
- Vendor needs to open vendor app
- Login
- App should automatically register FCM token

### **Check 2: Edge Function Logs**
- Go to Supabase Dashboard → Edge Functions → Logs
- Check for `send-push-notification` function logs
- Look for errors or successful sends

### **Check 3: App Status**
- Is vendor app open?
- Is vendor logged in?
- Check app notification settings

---

## 📋 **WHAT TO SHARE**

**After running the test, share:**

1. **Vendor FCM Tokens Check** - Do vendors have active tokens?
2. **Test Notification results** - Did they return success?
3. **pg_net Queue** - Are notification requests in queue?
4. **Did vendors receive notifications?** - Check vendor apps
5. **Booking update verification** - Was booking updated?

---

## ✅ **EXPECTED RESULTS**

### **Test Notifications:**
- Both vendors should receive: "Test Notification - Vendor App"
- Check vendor apps immediately after running test

### **Booking Status Change:**
- Vendor (Sun City Farmhouse) should receive: "Order Completed"
- Message: "Order for [service_name] has been completed"

---

**Run the test and check vendor apps for notifications!**
