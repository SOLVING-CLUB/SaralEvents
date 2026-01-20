# Push Notifications Setup Guide

## Overview
This guide implements push notifications using **Firebase Cloud Messaging (FCM)** integrated with **Supabase**. This is the recommended approach for Flutter apps using Supabase as the backend.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Supabase  │────▶│ Edge Function│────▶│  Firebase   │
│  Database   │     │  (or Trigger)│     │     FCM     │
└─────────────┘     └──────────────┘     └─────────────┘
       ▲                                         │
       │                                         ▼
┌─────────────┐                          ┌─────────────┐
│   Flutter   │◀─────────────────────────│   Device    │
│     App     │      Push Notification    │             │
└─────────────┘                          └─────────────┘
```

## Step 1: Firebase Setup

### 1.1 Enable Firebase Cloud Messaging
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `saraleventsnew`
3. Go to **Project Settings** → **Cloud Messaging**
4. Enable **Cloud Messaging API (Legacy)** if not already enabled
5. Note your **Server Key** (you'll need this for Supabase)

### 1.2 Update google-services.json
- Ensure your `google-services.json` is up to date
- The file should be in `android/app/google-services.json`
- For iOS, you'll need `GoogleService-Info.plist` in `ios/Runner/`

## Step 2: Database Schema

Create a table to store FCM tokens:

```sql
-- FCM Tokens Table
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  device_type TEXT NOT NULL CHECK (device_type IN ('android', 'ios', 'web')),
  device_id TEXT, -- Optional: unique device identifier
  app_version TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user 
  ON fcm_tokens(user_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_token 
  ON fcm_tokens(token);

-- RLS Policies
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own tokens"
  ON fcm_tokens FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tokens"
  ON fcm_tokens FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tokens"
  ON fcm_tokens FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tokens"
  ON fcm_tokens FOR DELETE
  USING (auth.uid() = user_id);
```

## Step 3: Supabase Edge Function (Recommended)

Create a Supabase Edge Function to send notifications via FCM.

### 3.1 Create Edge Function
```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Create edge function
supabase functions new send-push-notification
```

### 3.2 Edge Function Code
Location: `supabase/functions/send-push-notification/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY') || ''

serve(async (req) => {
  try {
    const { userId, title, body, data, tokens } = await req.json()

    if (!FCM_SERVER_KEY) {
      return new Response(
        JSON.stringify({ error: 'FCM_SERVER_KEY not configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // If tokens not provided, fetch from database
    let targetTokens = tokens
    if (!targetTokens || targetTokens.length === 0) {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )
      
      const { data: tokenData, error } = await supabase
        .from('fcm_tokens')
        .select('token')
        .eq('user_id', userId)
        .eq('is_active', true)
      
      if (error) throw error
      targetTokens = tokenData?.map(t => t.token) || []
    }

    if (targetTokens.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No active tokens found' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Send to FCM
    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${FCM_SERVER_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        registration_ids: targetTokens,
        notification: {
          title,
          body,
        },
        data: data || {},
      }),
    })

    const result = await fcmResponse.json()
    
    return new Response(
      JSON.stringify({ success: true, result }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

### 3.3 Deploy Edge Function
```bash
# Set FCM Server Key as secret
supabase secrets set FCM_SERVER_KEY=your-fcm-server-key

# Deploy function
supabase functions deploy send-push-notification
```

## Step 4: Database Triggers (Alternative to Edge Functions)

If you prefer database triggers, create triggers that call the edge function:

```sql
-- Function to send notification via Edge Function
CREATE OR REPLACE FUNCTION send_push_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT '{}'::JSONB
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_response JSONB;
BEGIN
  -- Call Supabase Edge Function via HTTP
  SELECT content::JSONB INTO v_response
  FROM http((
    'POST',
    current_setting('app.supabase_url') || '/functions/v1/send-push-notification',
    ARRAY[
      http_header('Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')),
      http_header('Content-Type', 'application/json')
    ],
    'application/json',
    json_build_object(
      'userId', p_user_id,
      'title', p_title,
      'body', p_body,
      'data', p_data
    )::TEXT
  )::http_request);
END;
$$;

-- Example: Trigger on order status change
CREATE OR REPLACE FUNCTION notify_order_update()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status != OLD.status THEN
    PERFORM send_push_notification(
      NEW.user_id,
      'Order Update',
      'Your order status has been updated to ' || NEW.status,
      jsonb_build_object(
        'type', 'order_update',
        'order_id', NEW.id,
        'status', NEW.status
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_status_notification
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION notify_order_update();
```

## Step 5: Flutter Implementation

See the implementation files:
- `lib/services/push_notification_service.dart` - FCM token management
- `lib/services/notification_handler.dart` - Handle incoming notifications
- Updated `lib/main.dart` - Initialize FCM

## Step 6: Usage Examples

### Send Notification from Backend (Edge Function)
```typescript
// Call from Supabase Edge Function or any backend
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
      body: 'Your payment of ₹5000 has been processed',
      data: {
        type: 'payment',
        orderId: 'order-123',
        amount: 5000,
      },
    }),
  }
)
```

### Send Notification from Database Trigger
```sql
-- Automatically sends notification when order is created
SELECT send_push_notification(
  'user-uuid',
  'New Order',
  'Your order has been confirmed',
  '{"type": "order", "order_id": "123"}'::JSONB
);
```

## Notification Types

1. **Transactions**: Payment success/failure
2. **Orders**: Status updates, confirmations
3. **Updates**: App updates, feature announcements
4. **Support**: Messages from support team
5. **Reminders**: Booking reminders, event reminders

## Testing

1. Register a device token in the app
2. Test via Supabase Dashboard → Edge Functions → Invoke
3. Or use the database function directly

## Security Notes

- Store FCM Server Key as Supabase secret (never in code)
- Use RLS policies to protect FCM tokens table
- Validate user permissions before sending notifications
- Rate limit notification sending to prevent abuse
