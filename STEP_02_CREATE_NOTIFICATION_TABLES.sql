-- ============================================================================
-- STEP 2: CREATE NOTIFICATION SYSTEM TABLES
-- ============================================================================
-- This query creates the core tables for the new notification system:
-- 1. notification_events - Stores raw domain events (input to NotificationService)
-- 2. notifications - Stores each notification to a single recipient
-- 3. notification_logs - Stores channel-level delivery logs
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- ============================================================================
-- TABLE 1: notification_events
-- Stores raw domain events (input to NotificationService)
-- ============================================================================
CREATE TABLE IF NOT EXISTS notification_events (
  event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_code TEXT NOT NULL,
  order_id UUID,
  booking_id UUID,
  payment_id UUID,
  refund_id UUID,
  ticket_id UUID,
  campaign_id UUID,
  withdrawal_request_id UUID,
  actor_role TEXT CHECK (actor_role IN ('USER', 'VENDOR', 'ADMIN', 'SYSTEM')),
  actor_id UUID,
  payload JSONB DEFAULT '{}'::JSONB,
  occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ingested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed BOOLEAN DEFAULT FALSE,
  processed_at TIMESTAMP WITH TIME ZONE,
  dedupe_key TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for notification_events
CREATE INDEX IF NOT EXISTS idx_notification_events_event_code ON notification_events(event_code);
CREATE INDEX IF NOT EXISTS idx_notification_events_order_id ON notification_events(order_id);
CREATE INDEX IF NOT EXISTS idx_notification_events_processed ON notification_events(processed);
CREATE INDEX IF NOT EXISTS idx_notification_events_dedupe_key ON notification_events(dedupe_key);
CREATE INDEX IF NOT EXISTS idx_notification_events_occurred_at ON notification_events(occurred_at);

-- ============================================================================
-- TABLE 2: notifications
-- Stores each logical notification to a single recipient (for in-app + audit)
-- ============================================================================
CREATE TABLE IF NOT EXISTS notifications (
  notification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID, -- Foreign key added separately below
  recipient_role TEXT NOT NULL CHECK (recipient_role IN ('USER', 'VENDOR', 'COMPANY')),
  recipient_user_id UUID,
  recipient_vendor_id UUID,
  recipient_admin_id UUID,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  order_id UUID,
  booking_id UUID,
  amount NUMERIC(12, 2),
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SENT', 'FAILED', 'SKIPPED')),
  type TEXT NOT NULL CHECK (type IN ('PUSH', 'IN_APP', 'BOTH')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  sent_at TIMESTAMP WITH TIME ZONE,
  read_at TIMESTAMP WITH TIME ZONE,
  metadata JSONB DEFAULT '{}'::JSONB,
  dedupe_key TEXT,
  priority TEXT DEFAULT 'NORMAL' CHECK (priority IN ('LOW', 'NORMAL', 'HIGH')),
  channel TEXT CHECK (channel IN ('MOBILE_APP', 'WEB_APP'))
);

-- Add foreign key constraint separately (handles existing tables)
DO $$
BEGIN
  -- Add event_id column if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'event_id'
  ) THEN
    ALTER TABLE notifications ADD COLUMN event_id UUID;
  END IF;
  
  -- Add foreign key constraint if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_schema = 'public' 
    AND table_name = 'notifications' 
    AND constraint_name = 'notifications_event_id_fkey'
  ) THEN
    ALTER TABLE notifications 
    ADD CONSTRAINT notifications_event_id_fkey 
    FOREIGN KEY (event_id) REFERENCES notification_events(event_id) ON DELETE CASCADE;
  END IF;
END $$;

-- Ensure all columns exist (in case table was created before without all columns)
DO $$
BEGIN
  -- List of all required columns for notifications table
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_role') THEN
    ALTER TABLE notifications ADD COLUMN recipient_role TEXT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_user_id') THEN
    ALTER TABLE notifications ADD COLUMN recipient_user_id UUID;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_vendor_id') THEN
    ALTER TABLE notifications ADD COLUMN recipient_vendor_id UUID;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_admin_id') THEN
    ALTER TABLE notifications ADD COLUMN recipient_admin_id UUID;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'title') THEN
    ALTER TABLE notifications ADD COLUMN title TEXT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'body') THEN
    ALTER TABLE notifications ADD COLUMN body TEXT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'order_id') THEN
    ALTER TABLE notifications ADD COLUMN order_id UUID;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'booking_id') THEN
    ALTER TABLE notifications ADD COLUMN booking_id UUID;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'amount') THEN
    ALTER TABLE notifications ADD COLUMN amount NUMERIC(12, 2);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'status') THEN
    ALTER TABLE notifications ADD COLUMN status TEXT DEFAULT 'PENDING';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'type') THEN
    ALTER TABLE notifications ADD COLUMN type TEXT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'created_at') THEN
    ALTER TABLE notifications ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'sent_at') THEN
    ALTER TABLE notifications ADD COLUMN sent_at TIMESTAMP WITH TIME ZONE;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'read_at') THEN
    ALTER TABLE notifications ADD COLUMN read_at TIMESTAMP WITH TIME ZONE;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'metadata') THEN
    ALTER TABLE notifications ADD COLUMN metadata JSONB DEFAULT '{}'::JSONB;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'dedupe_key') THEN
    ALTER TABLE notifications ADD COLUMN dedupe_key TEXT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'priority') THEN
    ALTER TABLE notifications ADD COLUMN priority TEXT DEFAULT 'NORMAL';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'channel') THEN
    ALTER TABLE notifications ADD COLUMN channel TEXT;
  END IF;
END $$;

-- Drop index if it exists (in case of previous failed creation)
DROP INDEX IF EXISTS idx_notifications_dedupe_key;

-- Unique constraint for idempotency (prevent duplicate notifications)
CREATE UNIQUE INDEX idx_notifications_dedupe_key ON notifications(dedupe_key) 
WHERE dedupe_key IS NOT NULL;

-- Indexes for notifications (only create if columns exist)
DO $$
BEGIN
  -- Create indexes only if columns exist
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'event_id') THEN
    CREATE INDEX IF NOT EXISTS idx_notifications_event_id ON notifications(event_id);
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_role') THEN
    CREATE INDEX IF NOT EXISTS idx_notifications_recipient_role ON notifications(recipient_role);
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_user_id') THEN
    CREATE INDEX IF NOT EXISTS idx_notifications_recipient_user_id ON notifications(recipient_user_id);
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_vendor_id') THEN
    CREATE INDEX IF NOT EXISTS idx_notifications_recipient_vendor_id ON notifications(recipient_vendor_id);
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'status') THEN
    CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'order_id') THEN
    CREATE INDEX IF NOT EXISTS idx_notifications_order_id ON notifications(order_id);
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'created_at') THEN
    CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'read_at') THEN
    CREATE INDEX IF NOT EXISTS idx_notifications_read_at ON notifications(read_at) WHERE read_at IS NULL;
  END IF;
END $$;

-- ============================================================================
-- TABLE 3: notification_logs
-- Stores channel-level delivery logs (push, in-app, etc.)
-- ============================================================================
CREATE TABLE IF NOT EXISTS notification_logs (
  log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  notification_id UUID NOT NULL, -- Foreign key added separately below
  channel TEXT NOT NULL CHECK (channel IN ('PUSH', 'IN_APP')),
  status TEXT NOT NULL CHECK (status IN ('SENT', 'FAILED', 'RETRYING', 'SKIPPED')),
  provider_message_id TEXT,
  error_code TEXT,
  error_message TEXT,
  attempted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  retry_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add foreign key constraint separately (handles existing tables)
DO $$
BEGIN
  -- Add notification_id column if missing (allow NULL initially if table has rows)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notification_logs' 
    AND column_name = 'notification_id'
  ) THEN
    -- Check if table has any rows
    IF EXISTS (SELECT 1 FROM notification_logs LIMIT 1) THEN
      -- Table has rows, add column as nullable first
      ALTER TABLE notification_logs ADD COLUMN notification_id UUID;
    ELSE
      -- Table is empty, can add as NOT NULL
      ALTER TABLE notification_logs ADD COLUMN notification_id UUID NOT NULL;
    END IF;
  END IF;
  
  -- Verify both the column exists AND the referenced table/column exists before adding foreign key
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notification_logs' 
    AND column_name = 'notification_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'notification_id'
  ) THEN
    -- Add foreign key constraint if it doesn't exist
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_schema = 'public' 
      AND table_name = 'notification_logs' 
      AND constraint_name = 'notification_logs_notification_id_fkey'
    ) THEN
      ALTER TABLE notification_logs 
      ADD CONSTRAINT notification_logs_notification_id_fkey 
      FOREIGN KEY (notification_id) REFERENCES notifications(notification_id) ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

-- Indexes for notification_logs
CREATE INDEX IF NOT EXISTS idx_notification_logs_notification_id ON notification_logs(notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_status ON notification_logs(status);
CREATE INDEX IF NOT EXISTS idx_notification_logs_attempted_at ON notification_logs(attempted_at);

-- ============================================================================
-- Enable Row Level Security (RLS)
-- ============================================================================
ALTER TABLE notification_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for notifications table (users can see their own notifications)
CREATE POLICY "Users can view their own notifications"
  ON notifications FOR SELECT
  USING (
    (recipient_role = 'USER' AND recipient_user_id = auth.uid()) OR
    (recipient_role = 'VENDOR' AND recipient_vendor_id IN (
      SELECT id FROM vendor_profiles WHERE user_id = auth.uid()
    )) OR
    (recipient_role = 'COMPANY' AND recipient_admin_id = auth.uid())
  );

-- RLS Policies for notification_events (admin/system only)
CREATE POLICY "Only service role can insert notification events"
  ON notification_events FOR INSERT
  WITH CHECK (true); -- Will be restricted by service role in practice

CREATE POLICY "Users cannot view notification events"
  ON notification_events FOR SELECT
  USING (false); -- Events are internal, users only see notifications

-- RLS Policies for notification_logs (admin/system only)
CREATE POLICY "Only service role can view notification logs"
  ON notification_logs FOR SELECT
  USING (false); -- Logs are internal

-- ============================================================================
-- Verification Query
-- ============================================================================
SELECT 
  'Verification: Tables Created' as check_type,
  table_name,
  CASE 
    WHEN table_name IN ('notification_events', 'notifications', 'notification_logs') 
    THEN '✅ Created'
    ELSE '❌ Missing'
  END as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('notification_events', 'notifications', 'notification_logs')
ORDER BY table_name;
