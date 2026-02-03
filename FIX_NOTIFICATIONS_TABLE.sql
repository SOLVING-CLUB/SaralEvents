-- ============================================================================
-- FIX NOTIFICATIONS TABLE STRUCTURE
-- ============================================================================
-- This script will update the existing notifications table to match the required structure
-- Run this if your notifications table has the wrong columns
-- ============================================================================

-- Step 1: Add missing columns
DO $$
BEGIN
  -- Add notification_id column (UUID primary key)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'notification_id'
  ) THEN
    ALTER TABLE notifications ADD COLUMN notification_id UUID DEFAULT uuid_generate_v4();
    
    -- Populate notification_id for existing rows
    UPDATE notifications 
    SET notification_id = uuid_generate_v4() 
    WHERE notification_id IS NULL;
    
    -- Make it NOT NULL
    ALTER TABLE notifications ALTER COLUMN notification_id SET NOT NULL;
    
    -- Add primary key constraint if old 'id' column exists
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'notifications' 
      AND column_name = 'id'
    ) THEN
      -- Drop old primary key if it exists
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_schema = 'public' 
        AND table_name = 'notifications' 
        AND constraint_type = 'PRIMARY KEY'
      ) THEN
        ALTER TABLE notifications DROP CONSTRAINT notifications_pkey;
      END IF;
      
      -- Add new primary key
      ALTER TABLE notifications ADD PRIMARY KEY (notification_id);
      
      -- Optionally drop old 'id' column (uncomment if you want to remove it)
      -- ALTER TABLE notifications DROP COLUMN id;
    ELSE
      -- No old id column, just add primary key
      ALTER TABLE notifications ADD PRIMARY KEY (notification_id);
    END IF;
  END IF;
  
  -- Add recipient_role
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'recipient_role'
  ) THEN
    ALTER TABLE notifications ADD COLUMN recipient_role TEXT;
  END IF;
  
  -- Add title
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'title'
  ) THEN
    ALTER TABLE notifications ADD COLUMN title TEXT;
  END IF;
  
  -- Add body
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'body'
  ) THEN
    ALTER TABLE notifications ADD COLUMN body TEXT;
  END IF;
  
  -- Add amount
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'amount'
  ) THEN
    ALTER TABLE notifications ADD COLUMN amount NUMERIC(12, 2);
  END IF;
  
  -- Add status
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'status'
  ) THEN
    ALTER TABLE notifications ADD COLUMN status TEXT DEFAULT 'PENDING';
  END IF;
  
  -- Add type
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'type'
  ) THEN
    ALTER TABLE notifications ADD COLUMN type TEXT;
  END IF;
  
  -- Add created_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'created_at'
  ) THEN
    ALTER TABLE notifications ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;
  
  -- Add sent_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'sent_at'
  ) THEN
    ALTER TABLE notifications ADD COLUMN sent_at TIMESTAMP WITH TIME ZONE;
  END IF;
  
  -- Add read_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'read_at'
  ) THEN
    ALTER TABLE notifications ADD COLUMN read_at TIMESTAMP WITH TIME ZONE;
  END IF;
  
  -- Add metadata
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'metadata'
  ) THEN
    ALTER TABLE notifications ADD COLUMN metadata JSONB DEFAULT '{}'::JSONB;
  END IF;
  
  -- Add dedupe_key
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'dedupe_key'
  ) THEN
    ALTER TABLE notifications ADD COLUMN dedupe_key TEXT;
  END IF;
  
  -- Add priority
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'priority'
  ) THEN
    ALTER TABLE notifications ADD COLUMN priority TEXT DEFAULT 'NORMAL';
  END IF;
  
  -- Add channel
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'channel'
  ) THEN
    ALTER TABLE notifications ADD COLUMN channel TEXT;
  END IF;
END $$;

-- Step 2: Add constraints
DO $$
BEGIN
  -- Add recipient_role constraint
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND constraint_name LIKE '%recipient_role%'
  ) THEN
    ALTER TABLE notifications 
    ADD CONSTRAINT notifications_recipient_role_check 
    CHECK (recipient_role IN ('USER', 'VENDOR', 'COMPANY'));
  END IF;
  
  -- Add status constraint
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND constraint_name LIKE '%status%'
  ) THEN
    ALTER TABLE notifications 
    ADD CONSTRAINT notifications_status_check 
    CHECK (status IN ('PENDING', 'SENT', 'FAILED', 'SKIPPED'));
  END IF;
  
  -- Add type constraint
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND constraint_name LIKE '%type%'
  ) THEN
    ALTER TABLE notifications 
    ADD CONSTRAINT notifications_type_check 
    CHECK (type IN ('PUSH', 'IN_APP', 'BOTH'));
  END IF;
  
  -- Add priority constraint
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND constraint_name LIKE '%priority%'
  ) THEN
    ALTER TABLE notifications 
    ADD CONSTRAINT notifications_priority_check 
    CHECK (priority IN ('LOW', 'NORMAL', 'HIGH'));
  END IF;
END $$;

-- Step 3: Add foreign key to notification_events
DO $$
BEGIN
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

-- Step 4: Create indexes
CREATE INDEX IF NOT EXISTS idx_notifications_event_id ON notifications(event_id);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_user_id ON notifications(recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_vendor_id ON notifications(recipient_vendor_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_role ON notifications(recipient_role);
CREATE INDEX IF NOT EXISTS idx_notifications_dedupe_key ON notifications(dedupe_key) WHERE dedupe_key IS NOT NULL;

-- Step 5: Verify the structure
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifications'
ORDER BY ordinal_position;
