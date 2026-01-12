# Booking Draft System Setup

## Issue: "Booking failed to save"

If you're seeing this error, it's likely because the `booking_drafts` table doesn't exist in your Supabase database.

## Solution

1. **Run the SQL schema file:**
   - Open your Supabase dashboard
   - Go to SQL Editor
   - Copy and paste the contents of `apps/user_app/booking_drafts_schema.sql`
   - Execute the SQL

2. **Verify the table was created:**
   - Go to Table Editor in Supabase
   - You should see `booking_drafts` table with the following columns:
     - `id` (UUID)
     - `user_id` (UUID)
     - `service_id` (UUID)
     - `vendor_id` (UUID)
     - `booking_date` (DATE)
     - `booking_time` (TIME)
     - `amount` (DECIMAL)
     - `notes` (TEXT)
     - `status` (TEXT)
     - `expires_at` (TIMESTAMPTZ)
     - `created_at` (TIMESTAMPTZ)
     - `updated_at` (TIMESTAMPTZ)

3. **Check RLS Policies:**
   - Make sure Row Level Security (RLS) is enabled
   - Verify the policies are created:
     - "Users can view their drafts"
     - "Users can create their drafts"
     - "Users can update their drafts"
     - "Users can delete their drafts"

## How the System Works

1. **User fills booking details** → Saved as draft (no booking created yet)
2. **User proceeds to payment** → Draft marked as `payment_pending`
3. **Payment succeeds** → Booking created from draft + advance milestone marked as paid
4. **User can view drafts** → Orders screen → "Drafts" tab → "Continue Booking" button

## Troubleshooting

### Error: "relation booking_drafts does not exist"
- **Solution:** Run `booking_drafts_schema.sql` in Supabase SQL Editor

### Error: "permission denied" or "policy violation"
- **Solution:** Check RLS policies are correctly set up
- Verify the user is authenticated

### Draft saves but booking not created after payment
- Check payment service logs for errors
- Verify the draft ID is being passed correctly
- Check that `createBooking` method is working

## Testing

1. Try saving a booking draft
2. Check if it appears in the "Drafts" tab in Orders screen
3. Complete payment flow
4. Verify booking is created after payment success
5. Check that draft status changes to "completed"

