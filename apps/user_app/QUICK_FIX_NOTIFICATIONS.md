# Quick Fix for Payment and Order Notifications

## ✅ Good News

Your triggers exist! I can see:
- ✅ `payment_success_notification` (INSERT)
- ✅ `payment_success_notification` (UPDATE)  
- ✅ `booking_status_change_notification` (UPDATE)

## ⚠️ Issues Found

1. **Duplicate Payment Triggers**: You have TWO `payment_success_notification` triggers (one for INSERT, one for UPDATE). This should be a single trigger handling both.

2. **Missing New Order Trigger**: No trigger for INSERT on bookings, so vendors don't get notified about new orders.

3. **pg_net Query Error**: The diagnostic script was using wrong column names.

## 🔧 Quick Fix

### Step 1: Run the Fixed Script

Run this in Supabase SQL Editor:

```sql
-- File: apps/user_app/fix_payment_order_notifications.sql
```

This will:
1. ✅ Consolidate payment triggers into one
2. ✅ Add new order notification trigger
3. ✅ Fix all trigger configurations

### Step 2: Verify

After running the fix, check triggers:

```sql
SELECT trigger_name, event_object_table, event_manipulation
FROM information_schema.triggers
WHERE trigger_name IN (
  'payment_success_notification',
  'booking_status_change_notification',
  'new_booking_notification'
)
ORDER BY event_object_table, trigger_name;
```

**Expected Result:**
- `payment_success_notification` → `payment_milestones` → `INSERT, UPDATE` (single trigger)
- `booking_status_change_notification` → `bookings` → `UPDATE`
- `new_booking_notification` → `bookings` → `INSERT` (new!)

### Step 3: Test

1. **Test New Order:**
   - Create a booking → Vendor should get "New Order Received"

2. **Test Payment:**
   - Complete payment → Both apps should get payment notifications

## 📝 What Changed

### Before:
- ❌ Two separate payment triggers (could cause duplicates)
- ❌ No trigger for new bookings (INSERT)
- ❌ Vendor never notified about new orders

### After:
- ✅ Single consolidated payment trigger
- ✅ New booking trigger for INSERT events
- ✅ Vendor gets notified when orders are created

## 🐛 If Still Not Working

Check these:

1. **Environment Variables:**
   ```sql
   SELECT 
     current_setting('app.supabase_url', true) as url,
     CASE WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
       THEN '✅ Set' ELSE '❌ Not set' END as key;
   ```

2. **Edge Function:**
   ```bash
   supabase functions list
   # Should show: send-push-notification
   ```

3. **FCM Tokens:**
   ```sql
   SELECT app_type, COUNT(*) 
   FROM fcm_tokens 
   WHERE is_active = true 
   GROUP BY app_type;
   ```

4. **Recent Requests:**
   ```sql
   SELECT id, url, status_code, error_msg, created_at
   FROM net.http_request_queue
   WHERE created_at >= NOW() - INTERVAL '1 hour'
   ORDER BY created_at DESC
   LIMIT 10;
   ```
