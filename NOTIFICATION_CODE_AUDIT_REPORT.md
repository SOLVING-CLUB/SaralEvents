# 📋 Notification Code Audit Report

## 🔍 Summary

This document lists all notification-related code found in all 3 apps and identifies what needs to be updated to use the new centralized notification system.

---

## 📱 **USER APP** (`apps/user_app`)

### Notification Services Found

#### 1. **`lib/services/notification_sender_service.dart`**
**Purpose:** Sends push notifications via edge function  
**Status:** ✅ **KEEP** - Still needed for direct push notifications  
**Location:** `apps/user_app/lib/services/notification_sender_service.dart`

**Functions:**
- `sendNotification()` - Generic push notification sender
- `sendOrderUpdate()` - Convenience method for order updates
- `sendPaymentNotification()` - Convenience method for payments
- `sendBookingConfirmation()` - Convenience method for booking confirmations

**Action Required:** ✅ **No changes needed** - This service is still valid for direct push notifications

---

#### 2. **`lib/services/order_notification_service.dart`**
**Purpose:** Manages in-app notifications from `order_notifications` table  
**Status:** ⚠️ **NEEDS UPDATE** - Uses old `order_notifications` table  
**Location:** `apps/user_app/lib/services/order_notification_service.dart`

**Functions:**
- `createNotification()` - Creates notification in `order_notifications` table
- `getUnreadNotifications()` - Gets unread notifications
- `getAllNotifications()` - Gets all notifications
- `markAsRead()` - Marks notification as read
- `markAllAsRead()` - Marks all as read
- `getUnreadCount()` - Gets unread count
- `getFilteredNotifications()` - Gets filtered notifications (24-hour rule)
- `notifyMilestoneUpdate()` - Creates milestone-specific notifications

**Action Required:** 🔄 **UPDATE REQUIRED**
- **Change:** Update to read from new `notifications` table instead of `order_notifications`
- **New table:** `notifications` (with `recipient_role = 'USER'` and `recipient_user_id`)
- **Columns mapping:**
  - `order_notifications.id` → `notifications.notification_id`
  - `order_notifications.booking_id` → `notifications.booking_id`
  - `order_notifications.order_id` → `notifications.order_id`
  - `order_notifications.user_id` → `notifications.recipient_user_id`
  - `order_notifications.title` → `notifications.title`
  - `order_notifications.message` → `notifications.body`
  - `order_notifications.is_read` → `notifications.read_at IS NOT NULL`
  - `order_notifications.created_at` → `notifications.created_at`

---

#### 3. **`lib/services/payment_service.dart`**
**Purpose:** Payment processing with notification sending  
**Status:** ⚠️ **NEEDS UPDATE** - Has manual notification code  
**Location:** `apps/user_app/lib/services/payment_service.dart`

**Notification Code Found:**
- Lines 279-590: Manual notification sending after payment success
- Lines 727-749: Manual notification sending after payment failure

**Action Required:** 🔄 **UPDATE REQUIRED**
- **Remove:** Manual notification sending code (lines 561-590, 743-749)
- **Reason:** Payment notifications are now handled automatically by database triggers
- **Keep:** Business logic, but remove notification calls

---

#### 4. **`lib/screens/notifications_screen.dart`**
**Purpose:** UI screen for displaying notifications  
**Status:** ⚠️ **NEEDS UPDATE** - Uses `OrderNotificationService`  
**Location:** `apps/user_app/lib/screens/notifications_screen.dart`

**Action Required:** 🔄 **UPDATE REQUIRED**
- **Change:** Update to use new `notifications` table via updated `OrderNotificationService`
- **No UI changes needed** - Just update the service it uses

---

### Summary for User App

| File | Status | Action Required |
|------|--------|-----------------|
| `notification_sender_service.dart` | ✅ Keep | No changes |
| `order_notification_service.dart` | ⚠️ Update | Change to read from `notifications` table |
| `payment_service.dart` | ⚠️ Update | Remove manual notification code |
| `notifications_screen.dart` | ⚠️ Update | Will work after service update |

---

## 🏪 **VENDOR APP** (`saral_events_vendor_app`)

### Notification Services Found

#### 1. **`lib/services/notification_sender_service.dart`**
**Purpose:** Sends push notifications via edge function  
**Status:** ✅ **KEEP** - Still needed for direct push notifications  
**Location:** `saral_events_vendor_app/lib/services/notification_sender_service.dart`

**Functions:**
- `sendNotification()` - Generic push notification sender

**Action Required:** ✅ **No changes needed**

---

#### 2. **`lib/features/bookings/booking_service.dart`**
**Purpose:** Booking management with notification sending  
**Status:** ⚠️ **NEEDS MAJOR UPDATE** - Has manual notification code  
**Location:** `saral_events_vendor_app/lib/features/bookings/booking_service.dart`

**Notification Code Found:**

**A. `markArrived()` function (lines 296-355):**
- Sends push notification via `NotificationSenderService`
- Creates notification in `order_notifications` table
- **Action:** Replace with `notify_vendor_arrived()` RPC call

**B. `markSetupCompleted()` function (lines 359-455):**
- Sends push notification via `NotificationSenderService`
- Creates notification in `order_notifications` table
- **Action:** Replace with `notify_vendor_setup_completed()` RPC call

**C. `cancelBookingAsVendor()` function (lines 458-570):**
- Sends push notification when vendor cancels
- **Action:** Keep push notification OR use `notify_vendor_cancelled_order()` RPC call

**D. `updateBookingStatus()` function (lines 188-238):**
- Creates notification in `order_notifications` table for completion
- **Action:** Remove - handled by database trigger

**E. `acceptBooking()` function (lines 240-293):**
- Creates notification in `order_notifications` table
- **Action:** Remove - handled by database trigger

**Action Required:** 🔄 **MAJOR UPDATE REQUIRED**

**Replace manual notification code with RPC calls:**

```dart
// OLD CODE (markArrived):
await _notificationSender.sendNotification(...);
await _supabase.from('order_notifications').insert(...);

// NEW CODE (markArrived):
await _supabase.rpc('notify_vendor_arrived', params: {
  'p_booking_id': bookingId,
  'p_order_id': null, // or order_id if using orders table
});
```

```dart
// OLD CODE (markSetupCompleted):
await _notificationSender.sendNotification(...);
await _supabase.from('order_notifications').insert(...);

// NEW CODE (markSetupCompleted):
await _supabase.rpc('notify_vendor_setup_completed', params: {
  'p_booking_id': bookingId,
  'p_order_id': null,
});
```

---

### Summary for Vendor App

| File | Status | Action Required |
|------|--------|-----------------|
| `notification_sender_service.dart` | ✅ Keep | No changes |
| `booking_service.dart` | ⚠️ Major Update | Replace manual notifications with RPC calls |

---

## 🖥️ **COMPANY WEB APP** (`apps/company_web`)

### Notification Code Found

#### 1. **`src/app/admin/dashboard/campaigns/page.tsx`**
**Purpose:** Campaign management and sending  
**Status:** ⚠️ **NEEDS UPDATE** - Calls edge function directly  
**Location:** `apps/company_web/src/app/admin/dashboard/campaigns/page.tsx`

**Notification Code Found:**
- Lines 295-410: `sendNotifications()` function
- Calls `supabase.functions.invoke('send-push-notification')` directly
- Loops through users and sends notifications

**Action Required:** 🔄 **UPDATE REQUIRED**

**Replace with RPC call:**
```typescript
// OLD CODE:
const results = await Promise.allSettled(
  uniqueUserIds.map(async userId => {
    const { data, error } = await supabase.functions.invoke('send-push-notification', {
      body: { userId, title, body, data, appTypes },
    });
    // ...
  })
);

// NEW CODE:
const { data, error } = await supabase.rpc('notify_campaign_broadcast', {
  p_campaign_id: campaign.id,
});
```

**Benefits:**
- Single RPC call instead of multiple edge function calls
- Automatic handling of all users/vendors
- Consistent with new notification system

---

#### 2. **`src/app/admin/dashboard/support/page.tsx`**
**Purpose:** Support ticket management  
**Status:** ⚠️ **NEEDS UPDATE** - Calls edge function directly  
**Location:** `apps/company_web/src/app/admin/dashboard/support/page.tsx`

**Notification Code Found:**
- Lines 204-288: `updateTicketStatus()` function
- Calls `supabase.functions.invoke('send-push-notification')` directly
- Sends notification when admin updates ticket status

**Action Required:** 🔄 **UPDATE REQUIRED**

**Current behavior:** Updates `support_tickets` table with `admin_notes`  
**New behavior:** Database trigger automatically sends notification when `admin_notes` is updated

**Option 1:** Keep current code (trigger will also fire - may cause duplicates)  
**Option 2:** Remove manual notification code (let trigger handle it)

**Recommended:** Remove manual notification code (lines 233-287) and let the database trigger handle it automatically.

---

#### 3. **`src/hooks/useRealtimeNotifications.ts`**
**Purpose:** Real-time notifications for admin dashboard  
**Status:** ✅ **KEEP** - For in-app admin notifications  
**Location:** `apps/company_web/src/hooks/useRealtimeNotifications.ts`

**Action Required:** ✅ **No changes needed** - This is for admin dashboard real-time updates, not user notifications

---

#### 4. **`src/lib/push-notification.ts`**
**Purpose:** Web push notification service  
**Status:** ✅ **KEEP** - For web push notifications  
**Location:** `apps/company_web/src/lib/push-notification.ts`

**Action Required:** ✅ **No changes needed** - This is for web push notifications in the company app

---

### Summary for Company Web App

| File | Status | Action Required |
|------|--------|-----------------|
| `campaigns/page.tsx` | ⚠️ Update | Replace with `notify_campaign_broadcast()` RPC call |
| `support/page.tsx` | ⚠️ Update | Remove manual notification code (trigger handles it) |
| `useRealtimeNotifications.ts` | ✅ Keep | No changes |
| `push-notification.ts` | ✅ Keep | No changes |

---

## 📊 **MIGRATION CHECKLIST**

### User App
- [ ] Update `order_notification_service.dart` to read from `notifications` table
- [ ] Remove manual notification code from `payment_service.dart`
- [ ] Test notification display in `notifications_screen.dart`

### Vendor App
- [ ] Replace `markArrived()` notification code with `notify_vendor_arrived()` RPC call
- [ ] Replace `markSetupCompleted()` notification code with `notify_vendor_setup_completed()` RPC call
- [ ] Remove manual notification code from `updateBookingStatus()` and `acceptBooking()`
- [ ] Optionally replace `cancelBookingAsVendor()` notification with RPC call

### Company Web App
- [ ] Replace campaign notification sending with `notify_campaign_broadcast()` RPC call
- [ ] Remove manual notification code from support ticket updates (let trigger handle it)

---

## 🔄 **MIGRATION EXAMPLES**

### Example 1: Vendor App - markArrived()

**BEFORE:**
```dart
// Push notify customer
await _notificationSender.sendNotification(
  userId: booking['user_id'],
  title: 'Vendor Arrived',
  body: 'Vendor marked arrival...',
  appTypes: ['user_app'],
  data: {...},
);

// Create notification record
await _supabase.from('order_notifications').insert({
  'booking_id': bookingId,
  'user_id': booking['user_id'],
  'notification_type': 'vendor_arrived',
  'title': 'Vendor Arrived',
  'message': '...',
});
```

**AFTER:**
```dart
// Single RPC call handles everything
await _supabase.rpc('notify_vendor_arrived', params: {
  'p_booking_id': bookingId,
  'p_order_id': null,
});
```

---

### Example 2: Company Web App - Campaign Sending

**BEFORE:**
```typescript
const results = await Promise.allSettled(
  uniqueUserIds.map(async userId => {
    const { data, error } = await supabase.functions.invoke('send-push-notification', {
      body: { userId, title, body, data, appTypes },
    });
    if (error) throw error;
    return data;
  })
);
```

**AFTER:**
```typescript
const { data, error } = await supabase.rpc('notify_campaign_broadcast', {
  p_campaign_id: campaign.id,
});

if (error) {
  console.error('Error broadcasting campaign:', error);
} else {
  console.log('Campaign broadcasted successfully');
}
```

---

### Example 3: User App - Reading Notifications

**BEFORE:**
```dart
final result = await _supabase
  .from('order_notifications')
  .select('*')
  .eq('user_id', userId)
  .eq('is_read', false)
  .order('created_at', ascending: false);
```

**AFTER:**
```dart
final result = await _supabase
  .from('notifications')
  .select('*')
  .eq('recipient_role', 'USER')
  .eq('recipient_user_id', userId)
  .is('read_at', null)  // Unread notifications
  .order('created_at', ascending: false);
```

---

## ⚠️ **IMPORTANT NOTES**

1. **Old `order_notifications` table:**
   - Still exists but should not be used for new notifications
   - Old notifications can remain for historical data
   - New notifications go to `notifications` table

2. **Database triggers:**
   - Most notifications are now automatic via triggers
   - Manual notification code should be removed to avoid duplicates

3. **RPC functions:**
   - Use RPC functions for manual notifications (vendor arrived, setup completed, etc.)
   - RPC functions handle both push and in-app notifications

4. **Testing:**
   - Test all notification flows after migration
   - Verify no duplicate notifications
   - Check that in-app notifications display correctly

---

## ✅ **NEXT STEPS**

1. **Create migration scripts** for each app
2. **Update notification services** to use new `notifications` table
3. **Replace manual notification code** with RPC calls
4. **Test thoroughly** to ensure no duplicates
5. **Monitor** notification delivery logs

---

**Last Updated:** After implementing new notification system  
**Status:** Ready for migration
