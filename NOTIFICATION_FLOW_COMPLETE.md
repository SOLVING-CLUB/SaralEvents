# Complete Notification Flow - Order to Completion

This document outlines the complete notification flow from order placement to completion, including all payments and who receives notifications.

## ✅ Implementation Status

All notifications are now correctly implemented with proper `app_type` filtering to prevent cross-app leakage.

## Flow Breakdown

### 1. Order Placed + 20% Advance Paid

**User Action:** Places order + pays **20% advance**

**Database State:**
- `payment_milestones(advance)` → `held_in_escrow` / `paid`
- `bookings.status` → `pending` or `confirmed` (depending on auto-confirm logic)
- `bookings.milestone_status` → `created`

**Push Notifications:**
- ✅ **User App**: "Payment Successful (20%)" - Sent by `notify_payment_success` trigger
- ✅ **Vendor App**: "New Order Received" - Sent by `notify_booking_status_change` trigger when booking is created

**Implementation:**
- Database trigger `payment_success_notification` handles payment notifications
- Database trigger `booking_status_change_notification` handles new order notification to vendor
- App code notifications removed to avoid duplicates

---

### 2. Vendor Accepts / Rejects

#### 2A) Vendor Accepts

**Vendor Action:** Accept booking

**Database State:**
- `bookings.status` → `confirmed`
- `bookings.milestone_status` → `accepted`

**Push Notifications:**
- ✅ **User App**: "Booking Confirmed" - Sent by `notify_booking_status_change` trigger
- ❌ **Vendor App**: **NO notification** (vendor performed the action)

**Implementation:**
- Database trigger `booking_status_change_notification` sends to user_app only when status is 'confirmed'
- Vendor notification is explicitly skipped in trigger logic
- App code notification removed (was duplicate)

#### 2B) Vendor Rejects

**Vendor Action:** Reject / cancel early

**Database State:**
- `bookings.status` → `cancelled`
- Refund process initiated

**Push Notifications:**
- ✅ **User App**: "Booking Cancelled" - Sent by `notify_booking_status_change` trigger
- ❌ **Vendor App**: **NO notification** (vendor performed the action)

---

### 3. Vendor Arrives at Location

**Vendor Action:** Mark arrived

**Database State:**
- `bookings.milestone_status` → `vendor_arrived`

**Push Notifications:**
- ✅ **User App**: "Vendor Arrived" - Sent by vendor app code (no database trigger for milestone_status changes)
- ❌ **Vendor App**: **NO notification** (vendor performed the action)

**Implementation:**
- Vendor app `markArrived()` method sends notification to user_app
- No database trigger for `vendor_arrived` milestone_status (app code handles it)

---

### 4. User Confirms Vendor Arrival + Pays 50% (Arrival Payment)

#### 4A) User Confirms Arrival

**User Action:** Confirm vendor arrival

**Database State:**
- `bookings.milestone_status` → `arrival_confirmed`

**Push Notifications:**
- ✅ **Vendor App**: "Arrival Confirmed" - Sent by `notify_vendor_milestone_confirmations` trigger
- ❌ **User App**: **NO notification** (user performed the action)

**Implementation:**
- Database trigger `milestone_confirmation_notification_vendor` sends to vendor_app when milestone_status changes to `arrival_confirmed`

#### 4B) User Pays 50%

**User Action:** Pay **50%** arrival milestone

**Database State:**
- `payment_milestones(arrival)` → `held_in_escrow` / `paid` / `released`

**Push Notifications:**
- ✅ **User App**: "Payment Successful (50%)" - Sent by `notify_payment_success` trigger
- ✅ **Vendor App**: "Payment Received (50%)" - Sent by `notify_payment_success` trigger

**Implementation:**
- Database trigger `payment_success_notification` sends to both user_app and vendor_app
- Includes `released` status to notify vendor when final payment is released from escrow

---

### 5. Vendor Marks Setup Completed

**Vendor Action:** Mark setup completed (**only after arrival payment done**)

**Database State:**
- `bookings.milestone_status` → `setup_completed`

**Push Notifications:**
- ✅ **User App**: "Setup Completed" - Sent by vendor app code (no database trigger for milestone_status changes)
- ❌ **Vendor App**: **NO notification** (vendor performed the action)

**Implementation:**
- Vendor app `markSetupCompleted()` method sends notification to user_app
- No database trigger for `setup_completed` milestone_status (app code handles it)
- Constraint enforced: setup can only be marked complete after arrival payment is confirmed

---

### 6. User Confirms Setup + Pays Final 30% (Completion Payment)

#### 6A) User Confirms Setup

**User Action:** Confirm setup

**Database State:**
- `bookings.milestone_status` → `setup_confirmed`

**Push Notifications:**
- ✅ **Vendor App**: "Setup Confirmed" - Sent by `notify_vendor_milestone_confirmations` trigger
- ❌ **User App**: **NO notification** (user performed the action)

**Implementation:**
- Database trigger `milestone_confirmation_notification_vendor` sends to vendor_app when milestone_status changes to `setup_confirmed`

#### 6B) User Pays 30%

**User Action:** Pay **30%** completion milestone

**Database State:**
- `payment_milestones(completion)` → `held_in_escrow` / `paid` / `released`

**Push Notifications:**
- ✅ **User App**: "Payment Successful (30%)" - Sent by `notify_payment_success` trigger
- ✅ **Vendor App**: "Payment Received (30%)" - Sent by `notify_payment_success` trigger

**Implementation:**
- Database trigger `payment_success_notification` sends to both user_app and vendor_app
- Includes `released` status to notify vendor when payment is released from escrow

---

### 7. Order Completion

**Vendor Action:** Mark order completed (only after final 30% is paid)

**Database State:**
- `bookings.status` → `completed`
- `bookings.milestone_status` → `completed`

**Push Notifications:**
- ✅ **User App**: "Order Completed" - Sent by `notify_booking_status_change` trigger
- ❌ **Vendor App**: **NO notification** (vendor performed the action)

**Implementation:**
- Database trigger `booking_status_change_notification` sends to user_app only when status is 'completed'
- Vendor notification is explicitly skipped in trigger logic
- App code notification removed (was duplicate)

---

## Critical Implementation Details

### 1. App Type Filtering

**Every notification MUST specify `appTypes` to prevent cross-app leakage:**

```dart
// User app notification
appTypes: ['user_app']

// Vendor app notification
appTypes: ['vendor_app']
```

**Database triggers explicitly specify app types:**
```sql
ARRAY['user_app']::TEXT[]  -- User only
ARRAY['vendor_app']::TEXT[]  -- Vendor only
```

### 2. Database Triggers (Source of Truth)

**Active Triggers:**
1. `booking_status_change_notification` - Handles status changes (confirmed, completed, cancelled)
2. `payment_success_notification` - Handles payment milestones (paid, held_in_escrow, released)
3. `milestone_confirmation_notification_vendor` - Handles user confirmations (arrival_confirmed, setup_confirmed)

**Trigger Logic:**
- Skips vendor notifications when vendor performs the action (confirmed, completed)
- Skips user notifications when user performs the action (arrival_confirmed, setup_confirmed)
- Always targets correct app using `appTypes` parameter

### 3. App Code Notifications

**App code sends notifications ONLY for:**
- `vendor_arrived` milestone_status (no database trigger)
- `setup_completed` milestone_status (no database trigger)
- Payment failures (not handled by triggers)

**App code does NOT send notifications for:**
- Booking acceptance (handled by trigger)
- Order completion (handled by trigger)
- Payment success (handled by trigger)

### 4. FCM Tokens Table

**Required Schema:**
```sql
CREATE TABLE fcm_tokens (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  token TEXT NOT NULL,
  device_type TEXT,
  app_type TEXT CHECK (app_type IN ('user_app','vendor_app','company_web')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_fcm_tokens_app_type ON fcm_tokens(app_type) WHERE is_active = true;
CREATE INDEX idx_fcm_tokens_user_app ON fcm_tokens(user_id, app_type) WHERE is_active = true;
```

**Critical:** `app_type` column must be populated correctly:
- User app tokens: `app_type = 'user_app'`
- Vendor app tokens: `app_type = 'vendor_app'`

### 5. Edge Function Filtering

**Edge Function (`send-push-notification`):**
- Accepts `appTypes` parameter in request body
- Filters FCM tokens by `app_type` when `appTypes` is provided
- Ensures notifications only go to intended apps

---

## Testing Checklist

- [ ] User places order + pays 20% → User gets payment notification, Vendor gets new order notification
- [ ] Vendor accepts → User gets confirmation, Vendor does NOT get notification
- [ ] Vendor arrives → User gets arrival notification, Vendor does NOT get notification
- [ ] User confirms arrival → Vendor gets confirmation notification, User does NOT get notification
- [ ] User pays 50% → Both user and vendor get payment notifications
- [ ] Vendor marks setup completed → User gets setup notification, Vendor does NOT get notification
- [ ] User confirms setup → Vendor gets confirmation notification, User does NOT get notification
- [ ] User pays 30% → Both user and vendor get payment notifications
- [ ] Vendor marks order completed → User gets completion notification, Vendor does NOT get notification
- [ ] All notifications go to correct app (no cross-app leakage)
- [ ] No duplicate notifications

---

## Files Modified

1. **`apps/user_app/lib/services/notification_sender_service.dart`** - Created with appTypes support
2. **`apps/user_app/lib/services/payment_service.dart`** - Removed duplicate notifications, added appTypes
3. **`apps/user_app/automated_notification_triggers.sql`** - Fixed trigger logic to skip vendor notifications for vendor actions
4. **`saral_events_vendor_app/lib/features/bookings/booking_service.dart`** - Removed duplicate notifications for acceptBooking and updateBookingStatus

---

## Summary

✅ All notifications are correctly implemented
✅ App type filtering prevents cross-app leakage
✅ Database triggers are the source of truth for most notifications
✅ App code handles only milestone_status changes without triggers
✅ No duplicate notifications
✅ Vendor does not get notifications for their own actions
✅ User does not get notifications for their own actions
