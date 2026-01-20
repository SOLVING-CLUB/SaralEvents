# Web Push Support for Edge Function

The Edge Function `send-push-notification` needs to be updated to support web push notifications using VAPID.

## VAPID Key Setup

1. Generate VAPID keys:
```bash
npm install -g web-push
web-push generate-vapid-keys
```

2. Set VAPID keys as Supabase secrets:
```bash
npx supabase secrets set VAPID_PUBLIC_KEY="your-public-key"
npx supabase secrets set VAPID_PRIVATE_KEY="your-private-key"
npx supabase secrets set VAPID_SUBJECT="mailto:your-email@example.com"
```

3. Add VAPID public key to company web app environment:
```env
NEXT_PUBLIC_VAPID_PUBLIC_KEY=your-public-key
```

## Edge Function Updates Needed

The Edge Function needs to:
1. Detect device type from token format
2. Use FCM API for mobile tokens (android/ios)
3. Use Web Push API for web tokens
4. Handle web push subscription JSON format

## Web Push Library

Add `web-push` library to Edge Function dependencies (Deno compatible version needed).
