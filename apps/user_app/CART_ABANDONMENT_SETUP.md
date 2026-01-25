# Cart Abandonment Notification - Complete Setup Guide

## ✅ Status: Fully Functional Setup

This guide will help you set up the cart abandonment notification system to run automatically every hour.

---

## 📋 Prerequisites

1. ✅ Edge Function code exists: `apps/user_app/supabase/functions/cart-abandonment-check/index.ts`
2. ✅ Database trigger exists: `cart_abandonment_notification` on `cart_items` table
3. ✅ Database column exists: `abandonment_notified_at` in `cart_items` table
4. ⚠️ Edge Function needs to be deployed
5. ⚠️ Scheduled job needs to be configured

---

## 🚀 Setup Steps

### Step 1: Deploy Edge Function

```bash
# Navigate to the functions directory
cd apps/user_app/supabase/functions

# Deploy the cart-abandonment-check function
supabase functions deploy cart-abandonment-check
```

**Or via Supabase Dashboard:**
1. Go to Supabase Dashboard > Edge Functions
2. Click "Create Function"
3. Name: `cart-abandonment-check`
4. Copy the code from `apps/user_app/supabase/functions/cart-abandonment-check/index.ts`
5. Deploy

---

### Step 2: Set Environment Variables

The Edge Function needs these environment variables (set automatically by Supabase):
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Your service role key

**Verify in Supabase Dashboard:**
1. Go to Edge Functions > `cart-abandonment-check` > Settings
2. Check that environment variables are set (they should be auto-set)

---

### Step 3: Schedule the Function

#### Option A: Using Supabase Dashboard (Recommended)

1. Go to **Supabase Dashboard** > **Database** > **Cron Jobs**
   - Or **Edge Functions** > **Cron** (depending on your Supabase version)

2. Click **"Create Cron Job"** or **"Schedule Function"**

3. Fill in the details:
   - **Name:** `cart-abandonment-check`
   - **Schedule:** `0 * * * *` (runs every hour at minute 0)
   - **Function:** `cart-abandonment-check`
   - **Payload:** `{}`
   - **Enabled:** ✅ Yes

4. Click **"Save"** or **"Create"**

#### Option B: Using SQL (if pg_cron is available)

Run the SQL script:
```sql
-- Run: apps/user_app/setup_cart_abandonment_schedule.sql
```

**Note:** pg_cron may not be available in all Supabase plans. If not available, use Option A.

---

### Step 4: Verify Setup

#### Check Scheduled Job
```sql
-- If using pg_cron, check the schedule:
SELECT 
  jobid,
  schedule,
  command,
  active
FROM cron.job
WHERE jobname = 'cart-abandonment-check';
```

#### Test Function Manually
```sql
-- Test the function manually:
SELECT net.http_post(
  url := 'https://your-project.supabase.co/functions/v1/cart-abandonment-check',
  headers := jsonb_build_object(
    'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true),
    'Content-Type', 'application/json'
  ),
  body := '{}'::jsonb
);
```

**Or via Supabase Dashboard:**
1. Go to Edge Functions > `cart-abandonment-check`
2. Click "Invoke" or "Test"
3. Check the logs for results

---

## 🔍 How It Works

### Scheduled Function (Primary Method)
1. **Runs every hour** at minute 0 (e.g., 1:00, 2:00, 3:00...)
2. **Finds cart items** that are:
   - Status = 'active'
   - Created 6+ hours ago
   - Not notified yet OR notified more than 24 hours ago
3. **Groups by user** to send one notification per user
4. **Sends push notification** via `send-push-notification` Edge Function
5. **Marks items as notified** by updating `abandonment_notified_at`

### Database Trigger (Backup Method)
- Still active and works when cart items are updated
- Provides immediate notification if item is updated after 6 hours
- Less reliable than scheduled function (only fires on UPDATE)

---

## 📊 Notification Details

### When Notifications Are Sent
- ✅ Cart items remain in cart for **6+ hours**
- ✅ User has **active** cart items
- ✅ Item hasn't been notified in the last **24 hours** (prevents spam)

### Notification Content
- **Title:** "Complete Your Order"
- **Body:** 
  - Single item: "Your [Service Name] is waiting in your cart. Complete your order now!"
  - Multiple items: "You have X items waiting in your cart. Complete your order now!"
- **Data Payload:**
  ```json
  {
    "type": "cart_abandonment",
    "cart_count": 2,
    "service_ids": ["uuid1", "uuid2"]
  }
  ```

### Recipient
- **User App only** (`appTypes: ['user_app']`)

---

## 🧪 Testing

### Create Test Cart Item
```sql
-- Insert a test cart item (6+ hours old)
INSERT INTO cart_items (
  user_id,
  service_id,
  vendor_id,
  title,
  category,
  price,
  status,
  created_at
) VALUES (
  'your-user-id'::UUID,
  'your-service-id'::UUID,
  'your-vendor-id'::UUID,
  'Test Service',
  'Test Category',
  1000.00,
  'active',
  NOW() - INTERVAL '7 hours' -- 7 hours ago
);
```

### Manually Trigger Check
```sql
-- Call the function manually
SELECT net.http_post(
  url := 'https://your-project.supabase.co/functions/v1/cart-abandonment-check',
  headers := jsonb_build_object(
    'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true),
    'Content-Type', 'application/json'
  ),
  body := '{}'::jsonb
);
```

### Verify Notification Sent
```sql
-- Check if item was marked as notified
SELECT 
  id,
  user_id,
  created_at,
  abandonment_notified_at,
  status
FROM cart_items
WHERE user_id = 'your-user-id'::UUID
AND status = 'active';
```

---

## 🐛 Troubleshooting

### Function Not Running
1. **Check Schedule:**
   - Verify cron job exists in Supabase Dashboard
   - Check if it's enabled
   - Verify schedule is correct (`0 * * * *`)

2. **Check Edge Function Logs:**
   - Go to Edge Functions > `cart-abandonment-check` > Logs
   - Look for errors or warnings

3. **Check Function Deployment:**
   - Verify function is deployed
   - Check function code is correct

### Notifications Not Received
1. **Check FCM Tokens:**
   ```sql
   SELECT * FROM fcm_tokens 
   WHERE user_id = 'your-user-id'::UUID 
   AND app_type = 'user_app' 
   AND is_active = true;
   ```

2. **Check Notification Function:**
   - Verify `send-push-notification` Edge Function is deployed
   - Check its logs for errors

3. **Check Cart Items:**
   ```sql
   SELECT 
     id,
     user_id,
     created_at,
     abandonment_notified_at,
     status
   FROM cart_items
   WHERE status = 'active'
   AND created_at <= NOW() - INTERVAL '6 hours';
   ```

### Duplicate Notifications
- The system prevents duplicates by:
  - Checking `abandonment_notified_at` before sending
  - Only re-notifying after 24 hours
  - Marking items as notified after sending

---

## 📝 Notes

- **Scheduled Function** is the primary method (runs every hour)
- **Database Trigger** is a backup (fires on UPDATE)
- Notifications are sent **once per user** (not per item)
- Items are marked as notified to prevent spam
- Re-notification allowed after 24 hours

---

## ✅ Verification Checklist

- [ ] Edge Function deployed
- [ ] Scheduled job created (every hour)
- [ ] Environment variables set
- [ ] Test cart item created (6+ hours old)
- [ ] Manual test successful
- [ ] Notification received in user app
- [ ] `abandonment_notified_at` updated
- [ ] No duplicate notifications

---

## 🎯 Expected Behavior

1. User adds items to cart
2. User doesn't complete order
3. After 6 hours, scheduled function runs
4. Function finds abandoned cart items
5. Notification sent to user app
6. Items marked as notified
7. If items still in cart after 24 hours, re-notification sent

---

## 📞 Support

If you encounter issues:
1. Check Edge Function logs
2. Check database trigger logs
3. Verify FCM tokens are registered
4. Test manually using SQL queries above
5. Check Supabase Dashboard for cron job status
