# Fix: Missing booking_status_change_notification Trigger

## 🚨 **PROBLEM IDENTIFIED**

**Missing Trigger:** `booking_status_change_notification` is **NOT in your database**!

**This trigger is critical for:**
- ✅ Notifying users when booking status changes (pending → confirmed → completed → cancelled)
- ✅ Notifying vendors when booking status changes (except when they perform the action)
- ✅ Order flow notifications

**Without this trigger:**
- ❌ Users won't get notified when booking is confirmed
- ❌ Users won't get notified when order is completed
- ❌ Users won't get notified when booking is cancelled
- ❌ Order flow notifications won't work

---

## ✅ **FIX: CREATE THE TRIGGER**

### **Step 1: Run This SQL**

**Run the SQL script:** `CREATE_MISSING_BOOKING_STATUS_TRIGGER.sql`

**Or run this directly:**

```sql
-- Create the function
CREATE OR REPLACE FUNCTION notify_booking_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_service_name TEXT;
  v_vendor_user_id UUID;
BEGIN
  -- Only send notification if status actually changed
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    -- Get service name
    SELECT name INTO v_service_name
    FROM services
    WHERE id = NEW.service_id;

    -- Get vendor's user_id
    SELECT user_id INTO v_vendor_user_id
    FROM vendor_profiles
    WHERE id = NEW.vendor_id;

    -- Notify user about status change
    PERFORM send_push_notification(
      NEW.user_id,
      CASE NEW.status
        WHEN 'confirmed' THEN 'Booking Confirmed'
        WHEN 'completed' THEN 'Order Completed'
        WHEN 'cancelled' THEN 'Booking Cancelled'
        ELSE 'Order Update'
      END,
      CASE NEW.status
        WHEN 'confirmed' THEN 
          COALESCE('Your booking for ' || v_service_name || ' has been confirmed!', 'Your booking has been confirmed!')
        WHEN 'completed' THEN 
          COALESCE('Your order for ' || v_service_name || ' has been completed. Thank you!', 'Your order has been completed.')
        WHEN 'cancelled' THEN 
          'Your booking has been cancelled. Refund will be processed as per policy.'
        ELSE 
          COALESCE('Your order for ' || v_service_name || ' status has been updated to ' || NEW.status, 
                   'Your order status has been updated to ' || NEW.status)
      END,
      jsonb_build_object(
        'type', 'booking_status_change',
        'booking_id', NEW.id::TEXT,
        'status', NEW.status,
        'old_status', OLD.status,
        'service_id', NEW.service_id::TEXT
      ),
      NULL,
      ARRAY['user_app']::TEXT[]
    );

    -- Notify vendor (only if vendor didn't perform the action)
    IF v_vendor_user_id IS NOT NULL AND NEW.status NOT IN ('confirmed', 'completed') THEN
      PERFORM send_push_notification(
        v_vendor_user_id,
        CASE NEW.status
          WHEN 'cancelled' THEN 'Booking Cancelled'
          ELSE 'Booking Status Update'
        END,
        CASE NEW.status
          WHEN 'cancelled' THEN 'A booking has been cancelled'
          ELSE COALESCE('Booking status updated to ' || NEW.status, 'Booking status updated')
        END,
        jsonb_build_object(
          'type', 'booking_status_change',
          'booking_id', NEW.id::TEXT,
          'status', NEW.status,
          'old_status', OLD.status,
          'service_id', NEW.service_id::TEXT
        ),
        NULL,
        ARRAY['vendor_app']::TEXT[]
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS booking_status_change_notification ON bookings;

CREATE TRIGGER booking_status_change_notification
  AFTER UPDATE ON bookings
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_booking_status_change();
```

### **Step 2: Verify Trigger Created**

```sql
SELECT 
  trigger_name,
  event_object_table,
  event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'booking_status_change_notification';
```

**Should show:** `booking_status_change_notification` on `bookings` table with `UPDATE` event.

### **Step 3: Test Order Flow**

**Test booking status change:**
1. Create a booking (vendor gets "New Order Received")
2. Vendor confirms booking (user gets "Booking Confirmed")
3. Complete order (user gets "Order Completed")
4. Check edge function logs for all notifications

---

## ✅ **WHAT THIS FIXES**

- ✅ Users get notified when booking is confirmed
- ✅ Users get notified when order is completed
- ✅ Users get notified when booking is cancelled
- ✅ Order flow notifications will work
- ✅ All status change notifications will work

---

## 📋 **COMPLETE TRIGGER LIST (After Fix)**

After creating the missing trigger, you should have:

1. ✅ `new_booking_notification` (INSERT on bookings) - Vendor gets "New Order Received"
2. ✅ `booking_status_change_notification` (UPDATE on bookings) - User/Vendor get status updates
3. ✅ `payment_success_notification` (INSERT/UPDATE on payment_milestones) - Both apps get payment notifications
4. ✅ `refund_initiated_notification` (INSERT on refunds) - User/Vendor get refund notifications
5. ✅ `refund_completed_notification` (UPDATE on refunds) - User gets refund completed
6. ✅ `cart_abandonment_notification` (UPDATE on cart_items) - User gets cart reminder
7. ✅ `milestone_confirmation_notification_vendor` (UPDATE on bookings) - Vendor gets milestone confirmations
8. ✅ `wallet_payment_released_notification` (INSERT on wallet_transactions) - Vendor gets payment released
9. ✅ `withdrawal_status_notification` (UPDATE on withdrawal_requests) - Vendor gets withdrawal updates

---

**Run the SQL to create the missing trigger, then test the order flow!**
