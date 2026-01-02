# Escrow Payment System - Implementation Guide

## Overview

This document describes the milestone-based escrow payment system implemented for Saral Events, similar to Zomato's order tracking flow. The system supports partial payments at different stages of service delivery.

## Payment Flow

```
Customer App
├─ Select Vendor & Service
├─ Create Booking
├─ Pay 20% Advance (held in escrow)
│
▼
Saral Events Escrow
│
▼
Vendor App
│
├─ Accept Booking
├─ Travel to Location
├─ Mark "Arrived at Location"
│
▼
Customer App
│
├─ Confirm Arrival
├─ Pay 50% (held in escrow)
│
▼
Vendor App
│
├─ Complete Setup
├─ Mark "Setup Completed"
│
▼
Customer App
│
├─ Confirm Setup
├─ Pay Remaining 30% (held in escrow)
│
▼
Admin Portal
│
├─ Verify Milestones
├─ Deduct Commission
├─ Credit Vendor Wallet
│
▼
Vendor App
│
└─ Withdraw to Bank Account
```

## Database Schema

### Tables Created

1. **payment_milestones** - Tracks individual payment milestones (20%, 50%, 30%)
2. **escrow_transactions** - Records escrow holds, releases, and commission deductions
3. **order_notifications** - Stores milestone-based notifications for users

### Milestone Status Flow

- `created` → Booking created, waiting for vendor acceptance
- `accepted` → Vendor accepted booking
- `vendor_traveling` → Vendor is traveling to location
- `vendor_arrived` → Vendor marked as arrived at location
- `arrival_confirmed` → Customer confirmed vendor arrival
- `setup_completed` → Vendor marked setup as completed
- `setup_confirmed` → Customer confirmed setup completion
- `completed` → All milestones completed

## Setup Instructions

### 1. Run Database Migration

Execute the SQL migration file to create the necessary tables and functions:

```bash
# Connect to your Supabase project and run:
psql -h <your-db-host> -U postgres -d postgres -f escrow_payment_system.sql
```

Or use Supabase SQL Editor to run the contents of `escrow_payment_system.sql`.

### 2. Update Booking Creation

The booking service has been updated to automatically:
- Set `milestone_status` to `'created'` when a booking is created
- Trigger automatic creation of payment milestones (20%, 50%, 30%) via database trigger

### 3. Payment Milestone Service

The `PaymentMilestoneService` provides methods to:
- Get milestones for a booking
- Get next pending milestone
- Mark milestone as paid and held in escrow
- Release milestone from escrow (admin action)
- Calculate payment progress

### 4. Order Tracking Screen

The `OrderTrackingScreen` provides a Zomato-like UI showing:
- Service information card
- Visual progress indicator with milestone steps
- Payment milestone details
- Payment summary (total, paid, remaining)
- Action buttons for payments and confirmations

## Usage Examples

### Creating a Booking with Escrow

```dart
final bookingService = BookingService(Supabase.instance.client);

final success = await bookingService.createBooking(
  serviceId: 'service-123',
  vendorId: 'vendor-456',
  bookingDate: DateTime.now().add(Duration(days: 7)),
  bookingTime: TimeOfDay(hour: 14, minute: 30),
  amount: 10000.0, // Total amount
  notes: 'Special requirements',
);

// This automatically creates 3 payment milestones:
// - Advance: ₹2000 (20%)
// - Arrival: ₹5000 (50%)
// - Completion: ₹3000 (30%)
```

### Processing Milestone Payment

```dart
final milestoneService = PaymentMilestoneService(Supabase.instance.client);

// Get next pending milestone
final nextMilestone = await milestoneService.getNextPendingMilestone(bookingId);

// After payment gateway success:
await milestoneService.markMilestonePaid(
  milestoneId: nextMilestone.id,
  paymentId: 'pay_xyz123',
  gatewayOrderId: 'order_abc456',
  gatewayPaymentId: 'pay_xyz123',
);
```

### Tracking Order Progress

```dart
// Navigate to order tracking screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => OrderTrackingScreen(
      bookingId: bookingId,
      serviceId: serviceId,
      vendorId: vendorId,
    ),
  ),
);
```

### Sending Notifications

```dart
final notificationService = OrderNotificationService(Supabase.instance.client);

// Notify user of milestone update
await notificationService.notifyMilestoneUpdate(
  bookingId: bookingId,
  userId: userId,
  milestoneStatus: 'vendor_arrived',
  orderId: orderId,
);
```

## Vendor App Integration (TODO)

The vendor app needs to be updated to:

1. **Accept Booking**
   ```dart
   // Update booking milestone_status to 'accepted'
   await supabase
     .from('bookings')
     .update({
       'milestone_status': 'accepted',
       'vendor_accepted_at': DateTime.now().toIso8601String(),
     })
     .eq('id', bookingId);
   ```

2. **Mark Traveling**
   ```dart
   await supabase
     .from('bookings')
     .update({
       'milestone_status': 'vendor_traveling',
       'vendor_traveling_at': DateTime.now().toIso8601String(),
     })
     .eq('id', bookingId);
   ```

3. **Mark Arrived**
   ```dart
   await supabase
     .from('bookings')
     .update({
       'milestone_status': 'vendor_arrived',
       'vendor_arrived_at': DateTime.now().toIso8601String(),
     })
     .eq('id', bookingId);
   ```

4. **Mark Setup Completed**
   ```dart
   await supabase
     .from('bookings')
     .update({
       'milestone_status': 'setup_completed',
       'setup_completed_at': DateTime.now().toIso8601String(),
     })
     .eq('id', bookingId);
   ```

## Admin Portal Integration (TODO)

The admin portal needs to:

1. **Verify Milestones** - Review milestone completion before releasing escrow
2. **Release Escrow** - Process escrow release with commission deduction
3. **Credit Vendor Wallet** - Transfer funds to vendor wallet after commission deduction

Example admin function:

```sql
-- Release milestone from escrow (with commission)
CREATE OR REPLACE FUNCTION release_milestone_with_commission(
  p_milestone_id UUID,
  p_admin_user_id UUID,
  p_commission_percentage DECIMAL DEFAULT 5.0
)
RETURNS BOOLEAN AS $$
DECLARE
  v_milestone RECORD;
  v_commission_amount DECIMAL(10, 2);
  v_vendor_amount DECIMAL(10, 2);
BEGIN
  -- Get milestone details
  SELECT * INTO v_milestone
  FROM payment_milestones
  WHERE id = p_milestone_id AND status = 'held_in_escrow';
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Calculate commission and vendor amount
  v_commission_amount := v_milestone.amount * (p_commission_percentage / 100);
  v_vendor_amount := v_milestone.amount - v_commission_amount;
  
  -- Create escrow transaction record
  INSERT INTO escrow_transactions (
    booking_id,
    milestone_id,
    transaction_type,
    amount,
    commission_amount,
    vendor_amount,
    status,
    admin_verified_by
  ) VALUES (
    v_milestone.booking_id,
    p_milestone_id,
    'release',
    v_milestone.amount,
    v_commission_amount,
    v_vendor_amount,
    'processing',
    p_admin_user_id
  );
  
  -- Update milestone status
  UPDATE payment_milestones
  SET status = 'released',
      escrow_released_at = NOW()
  WHERE id = p_milestone_id;
  
  -- Credit vendor wallet (implement wallet credit logic)
  -- UPDATE wallet_balances SET balance = balance + v_vendor_amount WHERE user_id = ...
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
```

## Notification System

Notifications are automatically created when milestones are updated. Users can:

- View unread notifications
- Mark notifications as read
- Get notification count
- Navigate to order tracking from notifications

## Testing Checklist

- [ ] Create booking and verify milestones are created
- [ ] Process advance payment (20%)
- [ ] Vendor accepts booking
- [ ] Vendor marks as traveling
- [ ] Vendor marks as arrived
- [ ] Customer confirms arrival
- [ ] Process arrival payment (50%)
- [ ] Vendor marks setup completed
- [ ] Customer confirms setup
- [ ] Process completion payment (30%)
- [ ] Admin verifies and releases escrow
- [ ] Vendor wallet is credited
- [ ] Notifications are sent at each milestone

## Next Steps

1. **Integrate payment gateway** - Connect milestone payments to Razorpay
2. **Vendor app updates** - Implement milestone marking in vendor app
3. **Admin portal** - Build escrow verification and release interface
4. **Push notifications** - Add Firebase/OneSignal for real-time notifications
5. **Wallet integration** - Connect vendor wallet credit system
6. **Refund handling** - Implement refund logic for cancelled bookings

## Files Created/Modified

- `escrow_payment_system.sql` - Database schema and functions
- `lib/services/payment_milestone_service.dart` - Milestone management service
- `lib/services/order_notification_service.dart` - Notification service
- `lib/screens/order_tracking_screen.dart` - Order tracking UI
- `lib/services/booking_service.dart` - Updated to set milestone_status

## Support

For questions or issues, refer to the main project documentation or contact the development team.

