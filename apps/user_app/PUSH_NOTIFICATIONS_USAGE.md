# Push Notifications Usage Guide

This guide explains how to use the push notification system in your Saral Events app.

## Overview

The push notification system consists of:
1. **PushNotificationService** - Registers FCM tokens when users log in
2. **NotificationSenderService** - Sends notifications via Edge Function
3. **Supabase Edge Function** - `send-push-notification` - Handles FCM API calls
4. **Database Triggers** - Automatically send notifications on events (optional)

## Setup Status

✅ Firebase initialized in `main.dart`  
✅ FCM tokens table created  
✅ Edge Function deployed  
✅ Service Account secret configured  
✅ PushNotificationService implemented  

## How It Works

### 1. Token Registration (Automatic)

When a user logs in, `PushNotificationService` automatically:
- Requests notification permissions
- Gets FCM token from Firebase
- Saves token to `fcm_tokens` table in Supabase
- Listens for token refresh and updates database

**No action needed** - this happens automatically!

### 2. Sending Notifications

#### Option A: From Flutter App (Client-Side)

```dart
import 'package:saral_events_user_app/services/notification_sender_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Initialize the service
final notificationSender = NotificationSenderService(Supabase.instance.client);

// Send a simple notification
await notificationSender.sendNotification(
  userId: 'user-uuid-here',
  title: 'Hello!',
  body: 'This is a test notification',
  data: {'type': 'test'},
);

// Send order update notification
await notificationSender.sendOrderUpdate(
  userId: 'user-uuid-here',
  orderId: 'order-123',
  status: 'confirmed',
);

// Send payment notification
await notificationSender.sendPaymentNotification(
  userId: 'user-uuid-here',
  orderId: 'order-123',
  amount: 5000.0,
  isSuccess: true,
);

// Send booking confirmation
await notificationSender.sendBookingConfirmation(
  userId: 'user-uuid-here',
  bookingId: 'booking-123',
  serviceName: 'Wedding Photography',
  bookingDate: DateTime.now(),
);
```

#### Option B: From Supabase Dashboard (Testing)

1. Go to **Edge Functions** → **send-push-notification** → **Invoke**
2. Use this payload:

```json
{
  "userId": "user-uuid-here",
  "title": "Test Notification",
  "body": "This is a test",
  "data": {
    "type": "test",
    "timestamp": "2024-01-01T00:00:00Z"
  }
}
```

#### Option C: From Database Triggers (Automatic)

See `notification_triggers.sql` for examples of automatic notifications on:
- Order status changes
- Booking confirmations
- Payment success
- Support ticket responses

**To enable triggers:**
1. Enable `http` extension in Supabase Dashboard → Database → Extensions
2. Set environment variables (see SQL file comments)
3. Run the SQL functions and triggers from `notification_triggers.sql`

#### Option D: From Backend/Server

```typescript
// Call Edge Function from any backend
const response = await fetch(
  `${SUPABASE_URL}/functions/v1/send-push-notification`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      userId: 'user-uuid',
      title: 'Payment Successful',
      body: 'Your payment has been processed',
      data: {
        type: 'payment',
        orderId: 'order-123',
      },
    }),
  }
);
```

## Notification Types

### 1. Order Updates
```dart
await notificationSender.sendOrderUpdate(
  userId: userId,
  orderId: orderId,
  status: 'confirmed',
  message: 'Your order has been confirmed', // Optional
);
```

### 2. Payment Notifications
```dart
await notificationSender.sendPaymentNotification(
  userId: userId,
  orderId: orderId,
  amount: 5000.0,
  isSuccess: true, // or false
);
```

### 3. Booking Confirmations
```dart
await notificationSender.sendBookingConfirmation(
  userId: userId,
  bookingId: bookingId,
  serviceName: 'Wedding Photography',
  bookingDate: DateTime(2024, 12, 25),
);
```

### 4. Support Messages
```dart
await notificationSender.sendSupportMessage(
  userId: userId,
  ticketId: ticketId,
  message: 'We have responded to your support ticket',
);
```

### 5. Custom Reminders
```dart
await notificationSender.sendReminder(
  userId: userId,
  title: 'Event Reminder',
  body: 'Your event is tomorrow!',
  data: {
    'type': 'reminder',
    'event_id': 'event-123',
  },
);
```

## Notification Data Payload

All notifications can include a `data` payload for app navigation:

```dart
{
  'type': 'order_update',      // Notification type
  'order_id': 'order-123',      // Order ID
  'status': 'confirmed',        // Status
  'service_id': 'service-456',  // Service ID
  // ... any other custom data
}
```

The app can use this data to navigate to specific screens when the notification is tapped.

## Handling Notifications in App

Notifications are handled in `PushNotificationService`:

- **Foreground**: `_handleForegroundMessage()` - App is open
- **Background**: `_handleBackgroundMessage()` - App is in background
- **Terminated**: Handled by `firebaseMessagingBackgroundHandler` in `main.dart`

You can extend these handlers to navigate to specific screens based on the `data.type` field.

## Testing

1. **Register a token**: Log in to the app (token is registered automatically)
2. **Check token in database**: 
   ```sql
   SELECT * FROM fcm_tokens WHERE user_id = 'your-user-id';
   ```
3. **Send test notification**: Use Supabase Dashboard → Edge Functions → Invoke
4. **Check logs**: Check Edge Function logs in Supabase Dashboard

## Troubleshooting

### Notifications not received?

1. **Check token registration**:
   ```sql
   SELECT * FROM fcm_tokens WHERE user_id = 'your-user-id' AND is_active = true;
   ```

2. **Check Edge Function logs**: Dashboard → Edge Functions → Logs

3. **Verify Firebase setup**: Ensure `google-services.json` is correct

4. **Check permissions**: User must grant notification permissions

5. **Verify secret**: Check that `FCM_SERVICE_ACCOUNT_BASE64` secret is set

### Edge Function errors?

- Check that the service account JSON is correctly base64 encoded
- Verify the project_id matches your Firebase project
- Check Edge Function logs for detailed error messages

## Security Notes

- ✅ FCM Service Account is stored as Supabase secret (secure)
- ✅ RLS policies protect `fcm_tokens` table
- ✅ Edge Function validates requests
- ⚠️ Don't expose service account JSON in client code
- ⚠️ Use service role key only on backend/server

## Next Steps

1. ✅ Test sending a notification via Dashboard
2. ✅ Integrate `NotificationSenderService` in your payment flow
3. ✅ Set up database triggers for automatic notifications
4. ✅ Add navigation handling for notification taps
5. ✅ Test on real devices (Android and iOS)

## Project ID Note

⚠️ **Important**: Your service account uses project ID `saralevents-6fe20`, but your `google-services.json` shows `saraleventsnew`. 

**Make sure these match**, or ensure:
- The `google-services.json` matches the Firebase project your app uses
- The service account JSON matches the project you want to send notifications from

If they're different projects, you may need to:
1. Download the correct `google-services.json` for `saralevents-6fe20`
2. Or create a service account for `saraleventsnew`
