# Booking Status Flow - Updated

## Overview
Vendor acceptance has been removed. Bookings are automatically accepted after payment completion.

## Status Flow

### After Payment Completion
- **Status**: `pending`
- **Milestone Status**: `NULL` (no vendor acceptance needed)
- Booking is immediately visible in the Bookings section

### After Task Completion (Vendor Action)
- **Status**: `completed`
- Vendor updates the booking status to `completed` when the task/service is finished
- This is done through the vendor app's booking management interface

### Cancellation
- **Status**: `cancelled`
- Can be done by either customer or vendor
- Follows refund policies based on category and time remaining

## Database Changes

### Removed Columns
- `vendor_accepted_at` - No longer needed
- `milestone_status` values: `'created'` and `'accepted'` - Removed from CHECK constraint

### Updated Columns
- `status` - Now only allows: `'pending'`, `'completed'`, `'cancelled'`
- `milestone_status` - Still used for payment milestone tracking (vendor_traveling, vendor_arrived, etc.) but no longer includes vendor acceptance states

## Code Changes

### Booking Creation (`booking_service.dart`)
- Removed `milestone_status: 'created'` from booking creation
- Status is set to `'pending'` after payment

### Order Tracking Screen (`order_tracking_screen.dart`)
- Removed "Vendor Accepted" step from progress indicator
- Updated progress calculation to handle null milestone_status
- Flow: Booking Confirmed → Vendor Arrived → Setup Completed → Order Completed

### Vendor App
- Vendors can update booking status from `pending` to `completed`
- Vendors can cancel bookings (triggers refund policy)

## SQL Migration

Run `remove_vendor_acceptance_columns.sql` in Supabase SQL Editor to:
1. Remove `vendor_accepted_at` column
2. Update `milestone_status` CHECK constraint
3. Update `status` CHECK constraint
4. Clean up existing bookings with old states

## Testing Checklist

- [ ] Payment completion creates booking with status `pending`
- [ ] Booking appears in Bookings section immediately after payment
- [ ] Vendor can update booking status to `completed`
- [ ] Order tracking screen shows correct progress (no vendor acceptance step)
- [ ] Cancellation works for both customer and vendor
- [ ] Refund policies apply correctly

