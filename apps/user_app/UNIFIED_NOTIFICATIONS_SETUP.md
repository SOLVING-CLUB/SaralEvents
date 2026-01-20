# Unified Push Notifications Setup Guide

This guide explains how push notifications work across all three applications:
- **User App** (Flutter) - For customers
- **Vendor App** (Flutter) - For service providers  
- **Company Web App** (Next.js) - For company admins

## Architecture Overview

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Supabase  │────▶│ Edge Function│────▶│  Firebase   │
│  Database   │     │  (send-push) │     │     FCM     │
└─────────────┘     └──────────────┘     └─────────────┘
       ▲                    │                    │
       │                    │                    │
       │                    ▼                    │
       │            ┌──────────────┐            │
       │            │  Web Push    │            │
       │            │   (VAPID)    │            │
       │            └──────────────┘            │
       │                                         │
       │                                         ▼
┌─────────────┐                          ┌─────────────┐
│   Flutter   │◀─────────────────────────│   Device    │
│     Apps    │      Push Notification   │             │
└─────────────┘                          └─────────────┘
       ▲                                         │
       │                                         │
       └─────────────────────────────────────────┘
              Web Push Notification
```

## Setup Status

### ✅ User App
- FCM packages added
- PushNotificationService implemented
- Firebase initialized
- Token registration working

### ✅ Vendor App  
- FCM packages added
- PushNotificationService implemented
- Firebase initialized
- Token registration working

### ⚠️ Company Web App
- Web push service created
- Service worker created
- **TODO**: VAPID keys setup
- **TODO**: Initialize in app

### ✅ Edge Function
- FCM support implemented
- **TODO**: Web push support (VAPID)

### ✅ Database
- `fcm_tokens` table created
- Supports android, ios, web
- Supports user_app, vendor_app, company_web

## Setup Steps

### 1. User App Setup (✅ Complete)
Already configured. Tokens register automatically on login.

### 2. Vendor App Setup (✅ Complete)
Already configured. Tokens register automatically on login.

**Note**: Vendor app needs `google-services.json` file:
1. Download from Firebase Console → Project `saralevents-6fe20`
2. Place in `saral_events_vendor_app/android/app/google-services.json`

### 3. Company Web App Setup

#### Step 3.1: Generate VAPID Keys
```bash
npm install -g web-push
web-push generate-vapid-keys
```

Save the output:
- **Public Key**: Add to `.env.local` as `NEXT_PUBLIC_VAPID_PUBLIC_KEY`
- **Private Key**: Add to Supabase secrets
- **Subject**: Your email (e.g., `mailto:admin@example.com`)

#### Step 3.2: Set Supabase Secrets
```bash
npx supabase secrets set VAPID_PUBLIC_KEY="your-public-key"
npx supabase secrets set VAPID_PRIVATE_KEY="your-private-key"
npx supabase secrets set VAPID_SUBJECT="mailto:admin@example.com"
```

#### Step 3.3: Update Company Web App Environment
Create/update `apps/company_web/.env.local`:
```env
NEXT_PUBLIC_VAPID_PUBLIC_KEY=your-public-key
```

#### Step 3.4: Initialize in Company Web App
Add to your main layout or auth context:

```typescript
import { pushNotificationService } from '@/lib/push-notification';

// In your auth context or main component
useEffect(() => {
  if (user) {
    pushNotificationService.initialize();
  }
}, [user]);
```

### 4. Update Edge Function for Web Push

The Edge Function needs to be updated to support web push. See `web-push-support.md` for details.

**Required updates:**
1. Add web-push library (Deno compatible)
2. Detect web tokens (JSON format)
3. Send web push using VAPID
4. Handle both FCM and web push

### 5. Database Schema Updates

Run the schema update:
```sql
-- Run in Supabase SQL Editor
\i fcm_tokens_schema_update.sql
```

This adds:
- `app_type` column (user_app, vendor_app, company_web)
- Support for web device_type
- Indexes for efficient queries

### 6. Notification Triggers

Run the unified triggers:
```sql
-- Run in Supabase SQL Editor
\i unified_notification_triggers.sql
```

**Before running:**
1. Enable `http` extension in Supabase Dashboard
2. Set environment variables:
   ```sql
   ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
   ALTER DATABASE postgres SET app.supabase_service_role_key = 'your-service-role-key';
   ```
3. Adjust table names to match your schema

## Notification Flow

### Order Flow Example

1. **User places order** → `orders` table INSERT
   - ✅ Trigger: `notify_vendor_new_order()` → Vendor App notified

2. **Vendor updates order status** → `orders` table UPDATE
   - ✅ Trigger: `notify_user_order_update()` → User App notified

3. **Payment completed** → `payments` table UPDATE
   - ✅ Trigger: `notify_payment_success()` → User App + Vendor App notified

### Booking Flow Example

1. **User confirms booking** → `bookings` table INSERT/UPDATE
   - ✅ Trigger: `notify_booking_confirmation()` → User App + Vendor App notified

## Testing

### Test User App Notification
```json
{
  "userId": "user-uuid",
  "title": "Test",
  "body": "Test notification",
  "appTypes": ["user_app"]
}
```

### Test Vendor App Notification
```json
{
  "userId": "vendor-uuid",
  "title": "Test",
  "body": "Test notification",
  "appTypes": ["vendor_app"]
}
```

### Test Company Web Notification
```json
{
  "userId": "admin-uuid",
  "title": "Test",
  "body": "Test notification",
  "appTypes": ["company_web"]
}
```

## Notification Types

All apps support these notification types:
- `order_update` - Order status changes
- `payment` - Payment success/failure
- `booking_confirmation` - Booking confirmed
- `new_order` - New order received (vendor)
- `payment_received` - Payment received (vendor)
- `booking_request` - New booking request (vendor)
- `support` - Support messages
- `campaign` - Marketing campaigns

## Troubleshooting

### Tokens not registering?
1. Check Firebase initialization
2. Check notification permissions
3. Check database `fcm_tokens` table
4. Check Edge Function logs

### Notifications not received?
1. Verify token is active: `SELECT * FROM fcm_tokens WHERE is_active = true`
2. Check Edge Function logs
3. Verify app_type matches
4. Test with Supabase Dashboard → Edge Functions → Invoke

### Web push not working?
1. Verify VAPID keys are set
2. Check service worker registration
3. Verify browser supports push
4. Check browser console for errors

## Next Steps

1. ✅ Complete vendor app `google-services.json` setup
2. ⚠️ Generate and configure VAPID keys
3. ⚠️ Update Edge Function for web push
4. ⚠️ Initialize web push in company app
5. ⚠️ Test all notification flows
6. ⚠️ Set up notification triggers

## Files Created

- `saral_events_vendor_app/lib/services/push_notification_service.dart`
- `apps/company_web/src/lib/push-notification.ts`
- `apps/company_web/public/sw.js`
- `apps/user_app/fcm_tokens_schema_update.sql`
- `apps/user_app/unified_notification_triggers.sql`
- `apps/user_app/UNIFIED_NOTIFICATIONS_SETUP.md`

## Support

For issues or questions:
1. Check Edge Function logs in Supabase Dashboard
2. Check browser console (for web app)
3. Check Flutter debug console (for mobile apps)
4. Review database `fcm_tokens` table
