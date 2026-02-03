# 📚 Notification System Quick Reference

## 🔍 Quick Function Reference

### Manual Notification Functions

| Function | Purpose | Parameters | Example |
|----------|---------|------------|---------|
| `notify_vendor_arrived()` | Vendor marks arrived | `p_order_id`, `p_booking_id` | `SELECT notify_vendor_arrived('order-id'::UUID);` |
| `notify_user_confirm_arrival()` | User confirms arrival | `p_order_id`, `p_booking_id` | `SELECT notify_user_confirm_arrival('order-id'::UUID);` |
| `notify_vendor_setup_completed()` | Vendor marks setup done | `p_order_id`, `p_booking_id` | `SELECT notify_vendor_setup_completed('order-id'::UUID);` |
| `notify_user_confirm_setup()` | User confirms setup | `p_order_id`, `p_booking_id` | `SELECT notify_user_confirm_setup('order-id'::UUID);` |
| `notify_campaign_broadcast()` | Admin sends campaign | `p_campaign_id` | `SELECT notify_campaign_broadcast('campaign-id'::UUID);` |
| `notify_vendor_decision()` | Vendor accepts/rejects | `p_order_id`, `p_booking_id`, `p_status` | `SELECT notify_vendor_decision('order-id'::UUID, NULL, 'accepted');` |
| `notify_user_cancelled_order()` | User cancels order | `p_order_id`, `p_booking_id` | `SELECT notify_user_cancelled_order('order-id'::UUID);` |
| `notify_vendor_cancelled_order()` | Vendor cancels order | `p_order_id`, `p_booking_id` | `SELECT notify_vendor_cancelled_order('order-id'::UUID);` |
| `notify_vendor_completed_order()` | Vendor completes order | `p_order_id`, `p_booking_id` | `SELECT notify_vendor_completed_order('order-id'::UUID);` |

### Core Functions

| Function | Purpose | Usage |
|----------|---------|-------|
| `process_notification_event()` | Core notification router | Called automatically by triggers or manually |
| `send_push_notification()` | Sends push notification | Called internally by `process_notification_event()` |

---

## 📋 Event Codes Reference

| Event Code | Description | Auto/Manual |
|------------|-------------|-------------|
| `ORDER_PAYMENT_SUCCESS` | Payment completed | Auto |
| `ORDER_PAYMENT_FAILED` | Payment failed | Auto |
| `ORDER_VENDOR_DECISION` | Vendor accepts/rejects | Auto |
| `ORDER_VENDOR_ARRIVED` | Vendor arrived | Manual |
| `ORDER_USER_CONFIRM_ARRIVAL` | User confirms arrival | Manual |
| `ORDER_VENDOR_SETUP_COMPLETED` | Setup completed | Manual |
| `ORDER_USER_CONFIRM_SETUP` | User confirms setup | Manual |
| `ORDER_VENDOR_COMPLETED` | Order completed | Auto |
| `PAYMENT_ANY_STAGE` | Payment at any stage | Auto |
| `ORDER_USER_CANCELLED` | User cancelled | Auto |
| `ORDER_VENDOR_CANCELLED` | Vendor cancelled | Auto |
| `VENDOR_REG_APPROVED` | Vendor approved | Auto |
| `SUPPORT_TICKET_UPDATED` | Ticket updated | Auto |
| `CAMPAIGN_BROADCAST` | Campaign sent | Manual |
| `REFUND_INITIATED` | Refund initiated | Auto |
| `REFUND_APPROVED` | Refund approved | Auto |
| `VENDOR_WITHDRAWAL_REQUESTED` | Withdrawal requested | Auto |
| `VENDOR_FUNDS_RELEASED_TO_WALLET` | Funds released | Auto |
| `VENDOR_WITHDRAWAL_APPROVED` | Withdrawal approved | Auto |

---

## 🗄️ Database Tables

| Table | Purpose |
|-------|---------|
| `notification_events` | Raw domain events (input) |
| `notifications` | Notifications per recipient (output) |
| `notification_logs` | Delivery logs (push, in-app) |

---

## 🔗 Integration Snippets

### Flutter/Dart (User App)

```dart
// Confirm vendor arrival
await supabase.rpc('notify_user_confirm_arrival', params: {
  'p_order_id': orderId,
});

// Confirm setup
await supabase.rpc('notify_user_confirm_setup', params: {
  'p_order_id': orderId,
});
```

### Flutter/Dart (Vendor App)

```dart
// Mark arrived
await supabase.rpc('notify_vendor_arrived', params: {
  'p_order_id': orderId,
});

// Mark setup completed
await supabase.rpc('notify_vendor_setup_completed', params: {
  'p_order_id': orderId,
});
```

### TypeScript/Next.js (Company App)

```typescript
// Send campaign
await supabase.rpc('notify_campaign_broadcast', {
  p_campaign_id: campaignId,
});
```

---

## 🐛 Debugging Queries

```sql
-- Check recent notifications
SELECT * FROM notifications ORDER BY created_at DESC LIMIT 20;

-- Check failed notifications
SELECT * FROM notifications WHERE status = 'FAILED';

-- Check notification events
SELECT * FROM notification_events ORDER BY occurred_at DESC LIMIT 20;

-- Check delivery logs
SELECT * FROM notification_logs WHERE status = 'FAILED';
```

---

## ✅ Checklist

- [ ] All 5 SQL queries executed successfully
- [ ] Edge function `/functions/v1/send-push-notification` is deployed
- [ ] Manual notification functions integrated in app code
- [ ] In-app notification UI implemented
- [ ] Testing completed for all notification flows
- [ ] Monitoring set up for failed notifications

---

**For detailed documentation, see:** `NOTIFICATION_SYSTEM_IMPLEMENTATION_COMPLETE.md`
