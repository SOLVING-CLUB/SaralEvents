# Push Notifications Quick Start Guide

## Step-by-Step Setup

### 1. Install Dependencies
```bash
cd apps/user_app
flutter pub get
```

### 2. Create Database Table
Run the SQL in `fcm_tokens_schema.sql` in your Supabase SQL Editor.

### 3. Enable Firebase
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `saraleventsnew`
3. Enable **Cloud Messaging API (Legacy)**
4. Get your **Server Key** from Project Settings → Cloud Messaging

### 4. Update google-services.json
- Ensure `android/app/google-services.json` is correct
- For iOS, add `GoogleService-Info.plist` to `ios/Runner/`

### 5. Configure Supabase Edge Function (Optional but Recommended)

#### Option A: Using Supabase Edge Function
```bash
# Install Supabase CLI
npm install -g supabase

# Login and link project
supabase login
supabase link --project-ref your-project-ref

# Create function
supabase functions new send-push-notification

# Set FCM Server Key as secret
supabase secrets set FCM_SERVER_KEY=your-fcm-server-key

# Deploy
supabase functions deploy send-push-notification
```

#### Option B: Using Database Triggers
See `PUSH_NOTIFICATIONS_SETUP.md` for trigger examples.

### 6. Test Push Notifications

#### From Flutter App (Testing)
```dart
// In your code, after user logs in
final pushService = PushNotificationService(Supabase.instance.client);
await pushService.initialize();
```

#### From Supabase Dashboard
1. Go to Edge Functions → `send-push-notification`
2. Click "Invoke"
3. Use this payload:
```json
{
  "userId": "user-uuid-here",
  "title": "Test Notification",
  "body": "This is a test notification",
  "data": {
    "type": "test"
  }
}
```

## Sending Notifications

### From Backend (Edge Function)
```typescript
// Call from any backend service
const response = await fetch(
  `${SUPABASE_URL}/functions/v1/send-push-notification`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      userId: 'user-uuid',
      title: 'Payment Successful',
      body: 'Your payment has been processed',
      data: {
        type: 'payment',
        orderId: '123',
      },
    }),
  }
);
```

### From Database Trigger
```sql
-- Example: Send notification when order status changes
SELECT send_push_notification(
  'user-uuid',
  'Order Update',
  'Your order status has been updated',
  '{"type": "order_update", "order_id": "123"}'::JSONB
);
```

## Notification Types

The app handles these notification types:
- `order_update` / `order` → Navigate to Orders
- `payment` → Navigate to Orders
- `support` / `message` → Navigate to Profile/Support
- `booking` / `booking_reminder` → Navigate to Orders
- `transaction` → Navigate to Orders

## Troubleshooting

### Token not registering
- Check Firebase is initialized
- Verify `google-services.json` is correct
- Check user is logged in
- Check Supabase RLS policies

### Notifications not received
- Verify FCM Server Key is set correctly
- Check device has internet connection
- Verify token is in `fcm_tokens` table
- Check notification permissions are granted

### Background notifications not working
- Ensure `firebaseMessagingBackgroundHandler` is top-level
- Check `@pragma('vm:entry-point')` annotation is present
