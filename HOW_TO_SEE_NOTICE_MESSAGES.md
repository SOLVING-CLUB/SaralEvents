# How to See NOTICE Messages

## 🔍 **IMPORTANT: NOTICE Messages**

When you run the UPDATE SQL, the trigger function will print NOTICE messages. These are **critical** for diagnosing the issue.

---

## 📋 **HOW TO SEE NOTICE MESSAGES**

### **In Supabase SQL Editor:**
1. Run the UPDATE SQL
2. Look at the **"Messages"** or **"Notifications"** tab/panel
3. You should see messages starting with "NOTICE:"

### **In Other SQL Clients:**
- **pgAdmin**: Check the "Messages" tab
- **DBeaver**: Check the "Log" or "Output" panel
- **psql**: Messages appear in the console
- **TablePlus**: Check the "Messages" section

---

## 🚀 **RUN THIS SQL**

**Run:** `UPDATE_PAYMENT_AND_SEE_LOGS.sql`

**Or run this directly:**

```sql
-- Update the payment - this will trigger the notification
UPDATE payment_milestones
SET status = 'held_in_escrow',
    updated_at = NOW()
WHERE id = '8d1f65aa-44f6-4142-9723-c60eeb23eff5';
```

---

## 📋 **WHAT TO LOOK FOR**

After running the UPDATE, you should see NOTICE messages like:

```
NOTICE: ========================================
NOTICE: notify_payment_success TRIGGER CALLED
NOTICE: TG_OP: UPDATE, OLD.status: pending, NEW.status: held_in_escrow
NOTICE: ✅ Status matches trigger condition
NOTICE: ✅ TG_OP condition matches - will send notification
NOTICE: ✅ Booking found: User ID = ...
NOTICE: Service: ..., Vendor User ID: ...
NOTICE: Sending notification to user...
NOTICE: ✅ User notification sent
NOTICE: Sending notification to vendor...
NOTICE: ✅ Vendor notification sent
NOTICE: ========================================
```

---

## 🔍 **IF YOU DON'T SEE NOTICE MESSAGES**

**Possible reasons:**
1. **SQL client doesn't show NOTICE messages** - Try a different client or check settings
2. **Trigger isn't firing** - Check if the trigger is actually attached
3. **Messages are hidden** - Check your SQL client's message/notification settings

**Alternative: Check PostgreSQL logs in Supabase Dashboard:**
- Go to Supabase Dashboard → Database → Logs
- Look for messages related to the trigger

---

## 📋 **WHAT TO SHARE**

**Please share:**
1. **ALL NOTICE messages** you see (if any)
2. **pg_net queue results** (from the query in the SQL file)
3. **Payment status** (to confirm it was updated)

**If you don't see any NOTICE messages:**
- Share that you don't see any messages
- Check Supabase Dashboard → Database → Logs
- Share any errors or warnings from the logs

---

**Run the UPDATE SQL and share the NOTICE messages!**
