# Test Vendor App Notifications

## 🧪 **TEST VENDOR APP NOTIFICATIONS**

### **Step 1: Run Test SQL**

**Run:** `TEST_VENDOR_APP_NOTIFICATION.sql`

**This will:**
1. Show vendor user_ids and FCM tokens
2. Send a test notification to vendor app
3. Check pg_net queue for notification request
4. Show a booking to test with

---

## 📋 **WHAT TO CHECK**

### **1. Vendor User & FCM Tokens**
- Check if vendor has `user_id`
- Check if vendor has active FCM token for `vendor_app`
- If no token, vendor needs to register FCM token in the app

### **2. Test Vendor Notification**
- Should return: `{"success":true,"request_id":X}`
- Check pg_net queue for notification request
- Check vendor app for notification

### **3. Check Vendor App**
- Open vendor app
- You should receive: "Test Notification - Vendor App"
- If not received, check:
  - FCM token is registered
  - App is in foreground/background
  - Edge function logs

---

## 🔧 **IF VENDOR HAS NO FCM TOKEN**

**The vendor needs to:**
1. Open vendor app
2. Login
3. App should automatically register FCM token
4. Check `fcm_tokens` table for new token

**Check FCM tokens:**
```sql
SELECT 
  user_id,
  app_type,
  is_active,
  created_at
FROM fcm_tokens
WHERE app_type = 'vendor_app'
  AND is_active = true
ORDER BY created_at DESC;
```

---

## 🧪 **TEST BOOKING STATUS CHANGE (Vendor Notification)**

**To test booking status change notification to vendor:**

1. **Get a booking:**
```sql
SELECT 
  b.id,
  b.vendor_id,
  vp.user_id as vendor_user_id
FROM bookings b
JOIN vendor_profiles vp ON vp.id = b.vendor_id
WHERE vp.user_id IS NOT NULL
LIMIT 1;
```

2. **Update booking status:**
```sql
UPDATE bookings
SET status = 'confirmed', -- or 'completed', 'cancelled'
    updated_at = NOW()
WHERE id = '<booking_id>';
```

3. **Vendor should receive notification:**
   - "Booking Confirmed by You" (if status = 'confirmed')
   - "Order Completed" (if status = 'completed')
   - "Booking Cancelled" (if status = 'cancelled')

---

## 📋 **WHAT TO SHARE**

**After running the test, share:**
1. **Vendor User & FCM Tokens** - Does vendor have active token?
2. **Test Vendor Notification result** - Did it return success?
3. **pg_net Queue** - Is notification request in queue?
4. **Did vendor receive notification?** - Check vendor app

---

**Run the test and share the results!**
