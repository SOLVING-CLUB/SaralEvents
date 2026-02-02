# Payment Trigger Live Test

## ✅ **GOOD NEWS**

The direct function test worked! This means:
- ✅ `send_push_notification` function is working
- ✅ Edge function can be called
- ✅ pg_net is working

## 🔍 **NEXT STEP: Test the Trigger**

The issue might be that the trigger isn't firing when payments are updated. Let's test it live.

### **Run: `TEST_PAYMENT_TRIGGER_LIVE.sql`**

**This will:**
1. Find a pending payment
2. Show payment details (user_id, vendor_id)
3. Check pg_net queue count BEFORE update
4. **Actually update a payment** (pending → held_in_escrow)
5. Check pg_net queue AFTER update (should show new request)
6. Verify the payment was updated

---

## 📋 **WHAT TO CHECK AFTER RUNNING**

### **1. Check the NOTICE messages**
The DO block will print:
- Payment ID
- Booking ID
- Old/New status
- Confirmation that update succeeded

### **2. Check pg_net Queue**
**After Update** should show:
- A new request with URL containing `send-push-notification`
- This confirms the trigger fired

### **3. Check Edge Function Logs**
Go to Supabase Dashboard → Edge Functions → Logs
- Should show notification being sent
- Check for any errors

### **4. Check Apps**
- User app should receive: "Payment Successful"
- Vendor app should receive: "Payment Received"

---

## 🔧 **IF TRIGGER DOESN'T FIRE**

**If pg_net queue doesn't show a new request after update:**

1. **Check trigger exists:**
```sql
SELECT trigger_name, event_object_table, event_manipulation
FROM information_schema.triggers
WHERE trigger_name = 'payment_success_notification';
```

2. **Check trigger condition:**
The trigger has `WHEN (NEW.status IN ('paid', 'held_in_escrow', 'released'))`
- This should fire when updating to 'held_in_escrow'
- If it doesn't, the trigger condition might be wrong

3. **Check function:**
```sql
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'notify_payment_success';
```

---

## 🧪 **ALTERNATIVE: Test with Existing Payment**

**If you want to test with an existing payment that's already 'held_in_escrow':**

```sql
-- Get a payment that's already held_in_escrow
SELECT id, booking_id, status
FROM payment_milestones
WHERE status = 'held_in_escrow'
LIMIT 1;

-- Update it to 'released' (this should also trigger)
UPDATE payment_milestones
SET status = 'released',
    updated_at = NOW()
WHERE id = '<payment_id>';
```

---

**Run the live test SQL and share:**
1. The NOTICE messages
2. pg_net queue results (before and after)
3. Payment update verification
4. Any errors
