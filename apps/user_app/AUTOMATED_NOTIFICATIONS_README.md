# Automated Notification Triggers - Implementation Guide

## Overview
Comprehensive automated notification system for User App and Vendor App that sends push notifications for key events without duplicates.

## ✅ Implemented Triggers

### 1. Cart Abandonment (6 hours)
**Trigger:** `cart_abandonment_notification` on `cart_items` table
**When:** Items remain in cart for 6+ hours
**Recipient:** User App
**Message:** "Complete Your Order" with item count

**Note:** For better coverage, use the scheduled Edge Function (see below)

### 2. Order Status Change
**Trigger:** `booking_status_change_notification` on `bookings` table
**When:** Booking status changes (pending → confirmed → completed → cancelled)
**Recipients:** User App + Vendor App
**Messages:** 
- User: "Booking Confirmed", "Order Completed", "Booking Cancelled"
- Vendor: "New Booking Confirmed", "Booking Completed", "Booking Cancelled"

**✅ Duplicates Removed:** Consolidated all booking status triggers into one

### 3. Payment Success
**Trigger:** `payment_success_notification` on `payment_milestones` table
**When:** Payment milestone status changes to 'paid' or 'held_in_escrow'
**Recipients:** User App + Vendor App
**Messages:**
- User: "Payment Successful"
- Vendor: "Payment Received"

### 4. Refund Initiated
**Trigger:** `refund_initiated_notification` on `refunds` table
**When:** Refund is created (status = 'pending')
**Recipients:** User App + Vendor App (if vendor cancelled)
**Messages:**
- User: "Refund Initiated"
- Vendor: "Refund Processed" (only if vendor cancelled)

### 5. Refund Completed
**Trigger:** `refund_completed_notification` on `refunds` table
**When:** Refund status changes to 'completed'
**Recipients:** User App
**Message:** "Refund Completed - Amount credited to your account"

### 6. Order Cancellation
**Handled by:** `booking_status_change_notification` trigger
**When:** Booking status changes to 'cancelled'
**Recipients:** User App + Vendor App
**Messages:** Includes refund information if available

## Setup Instructions

### Step 1: Run SQL Migration
Execute `automated_notification_triggers.sql` in your Supabase SQL Editor:

```sql
-- This will:
-- 1. Create/update send_push_notification() helper function
-- 2. Create all notification triggers
-- 3. Remove duplicate triggers
-- 4. Set up proper error handling
```

### Step 2: Configure Environment Variables
Set these in Supabase Dashboard → Settings → Database:

```sql
ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
ALTER DATABASE postgres SET app.supabase_service_role_key = 'your-service-role-key';
```

### Step 3: Enable HTTP Extension
In Supabase SQL Editor:

```sql
CREATE EXTENSION IF NOT EXISTS http;
```

### Step 4: Deploy Cart Abandonment Scheduled Function (Optional but Recommended)

1. **Deploy Edge Function:**
```bash
cd apps/user_app/supabase/functions
supabase functions deploy cart-abandonment-check
```

2. **Schedule via Supabase Cron:**
   - Go to Supabase Dashboard → Database → Cron Jobs
   - Create new cron job:
     - **Name:** `cart-abandonment-check`
     - **Schedule:** `0 * * * *` (every hour)
     - **Function:** `cart-abandonment-check`
     - **Payload:** `{}`

   Or use SQL:
```sql
-- Note: Requires pg_cron extension (may need to enable in Supabase)
SELECT cron.schedule(
  'cart-abandonment-check',
  '0 * * * *', -- Every hour
  $$
  SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/cart-abandonment-check',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

## Trigger Details

### Cart Abandonment
- **Table:** `cart_items`
- **Condition:** `status = 'active'` AND `created_at <= NOW() - INTERVAL '6 hours'`
- **Frequency:** On UPDATE (or via scheduled function every hour)
- **Prevents Duplicates:** Checks `updated_at` to avoid multiple notifications

### Order Status Change
- **Table:** `bookings`
- **Condition:** `OLD.status IS DISTINCT FROM NEW.status`
- **Frequency:** On UPDATE
- **Prevents Duplicates:** Single consolidated trigger (removed all duplicates)

### Payment Success
- **Table:** `payment_milestones`
- **Condition:** `NEW.status IN ('paid', 'held_in_escrow')` AND `OLD.status NOT IN ('paid', 'held_in_escrow')`
- **Frequency:** On INSERT or UPDATE
- **Prevents Duplicates:** Only fires on status transition

### Refund Initiated
- **Table:** `refunds`
- **Condition:** `NEW.status = 'pending'` (on INSERT)
- **Frequency:** On INSERT
- **Prevents Duplicates:** Only fires when refund is first created

### Refund Completed
- **Table:** `refunds`
- **Condition:** `NEW.status = 'completed'` AND `OLD.status != 'completed'`
- **Frequency:** On UPDATE
- **Prevents Duplicates:** Only fires on status transition to 'completed'

## Notification Data Payload

All notifications include relevant data in the `data` field:

```json
{
  "type": "event_type",
  "booking_id": "uuid",
  "order_id": "uuid",
  "refund_id": "uuid",
  "amount": "decimal",
  "status": "string",
  ...
}
```

## Duplicate Prevention

### ✅ Removed Duplicates
- Consolidated `order_status_notification_user` and `order_status_notification` into single trigger
- Removed `booking_confirmation_notification` (handled by status change trigger)
- Removed `new_order_notification_vendor` (handled by status change trigger)
- Single trigger per event type

### ✅ Prevention Mechanisms
1. **Status Transitions:** Triggers only fire on actual status changes
2. **Time Checks:** Cart abandonment checks `updated_at` to prevent duplicate notifications
3. **Conditional Logic:** Each trigger has specific conditions to avoid false positives

## Testing

### Test Cart Abandonment
```sql
-- Insert test cart item
INSERT INTO cart_items (user_id, service_id, vendor_id, title, category, price, status, created_at)
VALUES (
  'user-uuid',
  'service-uuid',
  'vendor-uuid',
  'Test Service',
  'Test Category',
  1000.00,
  'active',
  NOW() - INTERVAL '7 hours' -- 7 hours ago
);

-- Update to trigger notification
UPDATE cart_items SET updated_at = NOW() WHERE id = 'cart-item-id';
```

### Test Order Status Change
```sql
-- Update booking status
UPDATE bookings 
SET status = 'completed', updated_at = NOW()
WHERE id = 'booking-uuid';
```

### Test Payment Success
```sql
-- Update payment milestone
UPDATE payment_milestones 
SET status = 'paid', updated_at = NOW()
WHERE id = 'milestone-uuid';
```

### Test Refund Initiated
```sql
-- Create refund
INSERT INTO refunds (booking_id, cancelled_by, refund_amount, status)
VALUES ('booking-uuid', 'customer', 500.00, 'pending');
```

### Test Refund Completed
```sql
-- Update refund status
UPDATE refunds 
SET status = 'completed', processed_at = NOW()
WHERE id = 'refund-uuid';
```

## Monitoring

### Check Active Triggers
```sql
SELECT 
  trigger_name,
  event_object_table,
  action_statement,
  action_timing,
  event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND trigger_name LIKE '%notification%'
ORDER BY event_object_table;
```

### Check Notification Function
```sql
-- Test notification function
SELECT send_push_notification(
  'user-uuid',
  'Test Notification',
  'This is a test notification',
  '{"type": "test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

## Troubleshooting

### Notifications Not Sending
1. **Check HTTP Extension:** `SELECT * FROM pg_extension WHERE extname = 'http';`
2. **Check Environment Variables:** Verify `app.supabase_url` and `app.supabase_service_role_key` are set
3. **Check Edge Function:** Verify `send-push-notification` function is deployed
4. **Check Logs:** Review Supabase logs for trigger errors

### Duplicate Notifications
1. **Check Triggers:** Ensure only one trigger per event type exists
2. **Check Conditions:** Verify trigger conditions are specific enough
3. **Check Time Logic:** For cart abandonment, verify `updated_at` logic

### Cart Abandonment Not Working
1. **Use Scheduled Function:** The trigger only fires on UPDATE. Use the scheduled Edge Function for better coverage
2. **Check Time Logic:** Verify `created_at <= NOW() - INTERVAL '6 hours'` condition
3. **Check Status:** Ensure cart items have `status = 'active'`

## App Integration

### User App
- All notifications automatically sent to `user_app` via `appTypes` parameter
- Notifications appear in app notification center
- Deep links configured in notification data payload

### Vendor App
- Vendor notifications automatically sent to `vendor_app` via `appTypes` parameter
- Vendors receive notifications for:
  - New bookings
  - Booking status changes
  - Payment received
  - Refunds (if vendor cancelled)

## Future Enhancements

1. **Notification Preferences:** Allow users to opt-out of specific notification types
2. **Notification History:** Store all sent notifications in a table for analytics
3. **Rich Notifications:** Add images and action buttons
4. **Email Fallback:** Send email if push notification fails
5. **SMS Notifications:** Add SMS for critical events (payment, refund)
