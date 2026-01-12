# Booking Insert Fix - Troubleshooting Guide

## Problem
After payment, bookings are not being added to the `bookings` table. They don't appear in:
- User app "Bookings" section
- Vendor app orders

## Root Causes to Check

### 1. **RLS Policy Missing or Blocking**
The INSERT policy on `bookings` table might be missing or incorrectly configured.

**Fix:** Run `fix_booking_insert_policy.sql` in Supabase SQL Editor.

### 2. **Draft ID Not Set**
If the draft ID is null, booking creation is skipped.

**Check:** Look for these debug logs in the console:
```
=== PAYMENT PROCESSING START ===
Draft ID from parameter: [should not be null]
Draft ID from checkoutState: [should not be null]
```

### 3. **Booking Insert Error**
The insert might be failing due to:
- Constraint violation (status/milestone_status values)
- RLS blocking the insert
- Missing required fields

**Check:** Look for these error logs:
```
❌ ERROR inserting booking: [error message]
⚠️ Constraint violation detected!
⚠️ RLS policy issue detected!
```

## Steps to Fix

### Step 1: Run SQL Fix Script
Run `fix_booking_insert_policy.sql` in Supabase SQL Editor to ensure INSERT policy exists.

### Step 2: Check Debug Logs
After making a payment, check the Flutter console for:
1. `=== PAYMENT PROCESSING START ===` - Shows if draft ID is set
2. `=== BOOKING CREATION CHECK ===` - Shows if booking creation is attempted
3. `Creating booking from draft:` - Shows booking details
4. `Booking insert result:` - Shows if insert succeeded
5. Any error messages starting with `❌`

### Step 3: Run Diagnostic SQL
Run `diagnose_booking_insert.sql` to check:
- RLS status
- INSERT policies
- Recent bookings
- Constraints

### Step 4: Verify Draft Creation
Check if drafts are being created:
```sql
SELECT id, user_id, service_id, booking_date, event_date, status, created_at
FROM booking_drafts
WHERE user_id = auth.uid()
ORDER BY created_at DESC
LIMIT 5;
```

### Step 5: Test Booking Insert Manually
Try inserting a booking manually (replace UUIDs with actual values):
```sql
INSERT INTO bookings (
    user_id, 
    service_id, 
    vendor_id, 
    booking_date, 
    amount, 
    status, 
    milestone_status, 
    vendor_accepted_at
)
VALUES (
    auth.uid(),
    'your-service-id'::uuid,
    'your-vendor-id'::uuid,
    CURRENT_DATE,
    1000.00,
    'confirmed',
    'accepted',
    NOW()
)
RETURNING *;
```

If this fails, check the error message - it will tell you what's wrong.

## Expected Behavior After Fix

1. **During Payment:**
   - Draft ID should be logged
   - Booking creation should be attempted

2. **After Payment Success:**
   - Booking should be inserted into `bookings` table
   - Status should be `'confirmed'`
   - Milestone status should be `'accepted'`
   - `vendor_accepted_at` should be set

3. **In User App:**
   - Booking should appear in "Bookings" tab immediately
   - Status should show as "Confirmed"

4. **In Vendor App:**
   - Booking should appear in vendor's orders
   - Status should show as "Confirmed"

## Common Errors and Solutions

### Error: "permission denied for table bookings"
**Solution:** Run `fix_booking_insert_policy.sql` to create INSERT policy.

### Error: "violates check constraint"
**Solution:** Check that `status='confirmed'` and `milestone_status='accepted'` are allowed values.

### Error: "Draft not found"
**Solution:** Ensure draft is created before payment. Check `saveDraftFromCheckout` is called when billing details are saved.

### Error: "Booking date is required"
**Solution:** Ensure `event_date` is set in billing details, or `booking_date` is set in draft.

## Debug Checklist

- [ ] RLS INSERT policy exists on `bookings` table
- [ ] Draft is created before payment
- [ ] Draft ID is passed to `processPayment`
- [ ] `_currentDraftId` is set correctly
- [ ] Booking insert is attempted (check logs)
- [ ] No constraint violations (check logs)
- [ ] No RLS errors (check logs)
- [ ] Booking appears in database after insert

