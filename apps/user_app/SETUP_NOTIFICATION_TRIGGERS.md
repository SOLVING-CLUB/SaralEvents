# Setup Instructions for Automated Notification Triggers

## Error Fix: `http_response` type does not exist

If you're seeing the error:
```
ERROR: 42704: type "http_response" does not exist
```

This means the SQL file is trying to use the `http` extension, but Supabase uses `pg_net` extension instead.

## Solution

### Step 1: Enable pg_net Extension

Run this SQL command in your Supabase SQL Editor **BEFORE** running `automated_notification_triggers.sql`:

```sql
CREATE EXTENSION IF NOT EXISTS pg_net;
```

Or use the provided file:
```bash
# Run ENABLE_PG_NET_EXTENSION.sql first
```

### Step 2: Set Environment Variables

Set your Supabase URL and Service Role Key:

```sql
ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
ALTER DATABASE postgres SET app.supabase_service_role_key = 'your-service-role-key';
```

**Important:** Replace `your-project.supabase.co` with your actual Supabase project URL and `your-service-role-key` with your actual service role key.

### Step 3: Run the Migration

Now run `automated_notification_triggers.sql` in your Supabase SQL Editor.

## Verification

After running the migration, verify the extension is enabled:

```sql
SELECT * FROM pg_extension WHERE extname = 'pg_net';
```

You should see a row with `extname = 'pg_net'`.

## Testing

Test the notification function:

```sql
SELECT send_push_notification(
  'your-user-uuid-here',
  'Test Notification',
  'This is a test notification',
  '{"type": "test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

## Troubleshooting

### If pg_net extension is not available:

1. Check if your Supabase plan supports extensions
2. Some Supabase plans may require enabling extensions through the dashboard:
   - Go to Database → Extensions
   - Search for "pg_net"
   - Click "Enable"

### Alternative: Use Edge Functions Directly

If `pg_net` is not available, you can modify the triggers to call Edge Functions directly from your application code instead of using database triggers. However, `pg_net` is the recommended approach for Supabase.

## Notes

- `pg_net` is Supabase's native extension for making HTTP requests from PostgreSQL
- It's async, so notifications are queued and sent asynchronously
- The function returns immediately with a request ID
- Failed notifications are logged but don't fail the database transaction
