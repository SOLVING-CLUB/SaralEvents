# Payment and Order Notification Fix

## 🔍 Issue Identified

When a payment is completed from the user app:
1. ❌ **User app doesn't get payment notification**
2. ❌ **Vendor app doesn't get payment notification**  
3. ❌ **Vendor app doesn't get "New Order Received" notification**

## 🐛 Root Causes

### Issue 1: Missing New Order Notification Trigger
The `booking_status_change_notification` trigger only fires on **UPDATE**, not **INSERT**. So when a new booking is created:
- The trigger doesn't fire
- Vendor doesn't get "New Order Received" notification

**Current trigger:**
```sql
CREATE TRIGGER booking_status_change_notification
  AFTER UPDATE ON bookings  -- ❌ Only fires on UPDATE
  ...
```

### Issue 2: Payment Notification Trigger May Not Be Active
The `payment_success_notification` trigger should fire when payment milestones are created/updated, but it might:
- Not exist
- Be disabled
- Have incorrect conditions

## ✅ Solution

### Step 1: Run the Fix Script

Run this SQL script in Supabase SQL Editor:

```sql
-- File: apps/user_app/fix_payment_order_notifications.sql
```

This script will:
1. ✅ Create `notify_new_booking()` function for new orders
2. ✅ Create `new_booking_notification` trigger (fires on INSERT)
3. ✅ Verify `payment_success_notification` trigger exists and is correct
4. ✅ Verify `booking_status_change_notification` trigger exists

### Step 2: Verify Triggers Are Active

Run the diagnostic script:

```sql
-- File: apps/user_app/diagnose_payment_order_notifications.sql
```

This will show:
- Which triggers exist and are active
- Recent payment milestones and bookings
- pg_net request queue errors
- FCM token status

### Step 3: Test the Fix

1. **Test New Order Notification:**
   - Create a new booking from user app
   - Vendor app should receive "New Order Received" notification

2. **Test Payment Notification:**
   - Complete a payment from user app
   - Both apps should receive payment notifications:
     - User app: "Payment Successful"
     - Vendor app: "Payment Received"

## 📋 What the Fix Does

### New Booking Notification (INSERT Trigger)

```sql
CREATE TRIGGER new_booking_notification
  AFTER INSERT ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_booking();
```

**Sends to:** Vendor App only
**Message:** "New Order Received - You have a new order for [Service Name]. Amount: ₹[Amount]"

### Payment Success Notification (Already Exists)

```sql
CREATE TRIGGER payment_success_notification
  AFTER INSERT OR UPDATE ON payment_milestones
  FOR EACH ROW
  WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))
  EXECUTE FUNCTION notify_payment_success();
```

**Sends to:** 
- User App: "Payment Successful"
- Vendor App: "Payment Received"

## 🔧 Additional Checks

### 1. Verify send_push_notification Function

Make sure the function exists and has correct environment variables:

```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name = 'send_push_notification';
```

### 2. Check Environment Variables

```sql
SELECT 
  current_setting('app.supabase_url', true) as supabase_url,
  CASE 
    WHEN current_setting('app.supabase_service_role_key', true) IS NOT NULL 
    THEN '✅ Set'
    ELSE '❌ NOT set'
  END as service_role_key;
```

### 3. Check Edge Function

```bash
supabase functions list
# Should show: send-push-notification
```

### 4. Check pg_net Request Queue

```sql
SELECT 
  status,
  error_msg,
  created_at
FROM net.http_request_queue
WHERE created_at >= NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 10;
```

## 🧪 Testing Checklist

After running the fix:

- [ ] Create a new booking → Vendor receives "New Order Received"
- [ ] Complete payment (20% advance) → User receives "Payment Successful"
- [ ] Complete payment (20% advance) → Vendor receives "Payment Received"
- [ ] Check pg_net request queue for successful requests
- [ ] Check edge function logs for any errors

## 📝 Files Created

1. **`fix_payment_order_notifications.sql`** - Fix script to create missing triggers
2. **`diagnose_payment_order_notifications.sql`** - Diagnostic script to check current state

## 🚨 Important Notes

1. **New Order Notification:** Only fires on INSERT (when booking is first created)
2. **Payment Notification:** Fires on INSERT or UPDATE when status changes to paid/held_in_escrow/released
3. **Status Change Notification:** Only fires on UPDATE (when booking status changes)

## 🔄 If Still Not Working

1. **Check if triggers fired:**
   ```sql
   -- Check recent bookings
   SELECT * FROM bookings 
   WHERE created_at >= NOW() - INTERVAL '1 hour'
   ORDER BY created_at DESC;
   
   -- Check recent payments
   SELECT * FROM payment_milestones 
   WHERE updated_at >= NOW() - INTERVAL '1 hour'
   ORDER BY updated_at DESC;
   ```

2. **Check pg_net errors:**
   ```sql
   SELECT * FROM net.http_request_queue 
   WHERE status = 'ERROR' 
   AND created_at >= NOW() - INTERVAL '1 hour';
   ```

3. **Check edge function logs:**
   ```bash
   supabase functions logs send-push-notification --tail
   ```

4. **Verify FCM tokens exist:**
   ```sql
   SELECT app_type, COUNT(*) 
   FROM fcm_tokens 
   WHERE is_active = true 
   GROUP BY app_type;
   ```
