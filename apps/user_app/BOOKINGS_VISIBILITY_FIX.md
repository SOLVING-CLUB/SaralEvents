# Bookings Visibility Fix

## Problem
After successful payment, bookings are not showing up in the "Bookings" section of the Orders screen. They appear to be disappearing after payment.

## Root Causes Identified

1. **RLS Policy Conflicts**: Multiple conflicting RLS policies from previous sessions may be blocking access
2. **Function Permissions**: The `get_user_bookings` function may not have proper permissions to access related tables
3. **Cache Issues**: Stale cache may be showing old data
4. **Missing Policies**: Services and vendor_profiles tables may lack proper RLS policies needed for the JOIN in `get_user_bookings`

## Solution

### Step 1: Run the SQL Fix Script

**Run this SQL script in your Supabase SQL Editor:**

```sql
-- File: apps/user_app/fix_bookings_visibility.sql
```

This script will:
- Drop all conflicting RLS policies
- Recreate proper RLS policies for bookings, services, and vendor_profiles
- Recreate the `get_user_bookings` function with proper permissions
- Add necessary indexes for performance
- Verify table structure

### Step 2: Code Changes Made

#### 1. **BookingService** (`lib/services/booking_service.dart`)
- ✅ Added fallback direct query if RPC function fails
- ✅ Improved error logging
- ✅ Force cache invalidation after booking creation
- ✅ Better verification of booking creation

#### 2. **PaymentService** (`lib/services/payment_service.dart`)
- ✅ Added cache invalidation after booking creation
- ✅ Better error handling and logging

#### 3. **OrdersScreen** (`lib/screens/orders_screen.dart`)
- ✅ Added tab change listener to refresh bookings when switching tabs
- ✅ Auto-refresh when returning to bookings tab

### Step 3: Testing

After running the SQL script:

1. **Kill and restart the app** (to clear all caches)
2. **Create a test booking**:
   - Select a service
   - Fill booking details
   - Complete payment
3. **Check Bookings tab**:
   - Navigate to Orders → Bookings tab
   - The booking should appear immediately
   - If not, pull down to refresh

### Step 4: Verification Queries

Run these in Supabase SQL Editor to verify:

```sql
-- Check if bookings exist for your user
SELECT COUNT(*) FROM bookings WHERE user_id = auth.uid();

-- Test the function directly
SELECT * FROM get_user_bookings(auth.uid());

-- Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename = 'bookings';
```

## Expected Behavior After Fix

1. ✅ Booking is created in database after payment
2. ✅ Booking appears in Bookings tab immediately
3. ✅ Booking persists (doesn't disappear)
4. ✅ Pull-to-refresh works correctly
5. ✅ Cache is properly invalidated after booking creation

## Troubleshooting

### If bookings still don't show:

1. **Check database directly**:
   ```sql
   SELECT * FROM bookings WHERE user_id = '<your-user-id>' ORDER BY created_at DESC;
   ```

2. **Check function permissions**:
   ```sql
   SELECT proname, prosecdef, proconfig 
   FROM pg_proc 
   WHERE proname = 'get_user_bookings';
   ```

3. **Check RLS is enabled**:
   ```sql
   SELECT tablename, rowsecurity 
   FROM pg_tables 
   WHERE tablename = 'bookings';
   ```

4. **Check for errors in app logs**:
   - Look for "Error fetching user bookings" messages
   - Check if RPC function is failing

### If RPC function fails:

The code now has a **fallback direct query** that will:
- Query bookings table directly
- Join with services and vendor_profiles
- Format the response to match expected structure
- This ensures bookings show even if the function has issues

## Files Modified

1. ✅ `apps/user_app/fix_bookings_visibility.sql` - Comprehensive SQL fix
2. ✅ `apps/user_app/lib/services/booking_service.dart` - Improved error handling and fallback
3. ✅ `apps/user_app/lib/services/payment_service.dart` - Cache invalidation
4. ✅ `apps/user_app/lib/screens/orders_screen.dart` - Auto-refresh on tab change

## Next Steps

1. **Run the SQL script** in Supabase
2. **Restart the app**
3. **Test a complete booking flow**
4. **Verify bookings appear** in the Bookings tab

---

**Note**: The SQL script is idempotent - you can run it multiple times safely. It uses `DROP POLICY IF EXISTS` and `CREATE POLICY IF NOT EXISTS` to avoid conflicts.

