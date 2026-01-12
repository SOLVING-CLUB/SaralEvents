# Category-Wise Payment & Refund Policies - Implementation Guide

## Overview

This document describes the implementation of category-wise payment and refund policies for Saral Events, covering Customer App, Vendor App, and Admin Portal.

## Payment Structure

All bookings follow a **milestone-based payment structure**:

- **20% Advance** - Paid at booking creation
- **50% on Vendor Arrival** - Paid when vendor arrives and customer confirms
- **30% after Setup Completion** - Paid when setup is completed and customer confirms

All payments are held in **escrow** until admin verification and vendor wallet credit.

## Refund Policies by Category

### 1. Food & Catering Services
**Categories:** Catering, Food Preparation, Buffet Services, Cloud Kitchens

**Refund Policy:**
- **More than 7 days before event:** 100% of advance refunded
- **3-7 days before event:** 50% of advance refunded
- **Less than 72 hours:** No refund

### 2. Venues
**Categories:** Function Halls, Banquet Halls, Farmhouses, Marriage Gardens

**Refund Policy:**
- **More than 30 days before event:** 75% of advance refunded
- **15-30 days before event:** 50% of advance refunded
- **7-15 days before event:** 25% of advance refunded
- **Less than 7 days:** No refund

### 3. DJs, Musicians & Live Performers
**Categories:** DJ, Bands, Singers, Instrumentalists, Anchors

**Refund Policy:**
- **More than 7 days before event:** 75% of advance refunded
- **3-7 days before event:** 50% of advance refunded
- **Less than 72 hours:** No refund

### 4. Decorators & Event Essentials Providers
**Categories:** Decor, Flowers, Lighting, Stage, Tents, Chairs, Sound, Generators

**Refund Policy:**
- **More than 48 hours before event:** 75% of advance refunded
- **24-48 hours before event:** 50% of advance refunded
- **Less than 24 hours:** No refund

## Vendor Cancellation

When a vendor cancels a booking:

- **Customer receives:** 100% refund of all payments made
- **Vendor penalties:**
  - **First cancellation:** Wallet freeze (7 days) + Ranking reduction (30 days)
  - **Second cancellation:** All above + Visibility reduction (60 days)
  - **Third+ cancellation:** Suspension (90 days) or permanent blacklisting

## Multi-Vendor / Combo Bookings

For bookings involving multiple vendors:

- Cancellation and refunds are calculated **vendor-wise**
- Each vendor follows their respective category policy
- Customer sees:
  - Vendor-wise cancellation charges
  - Item-wise refund breakup
  - Overall refund may be partial depending on categories involved

## Implementation Details

### Database Schema

Run the following SQL files in order:

1. `refund_policy_schema.sql` - Creates refund tables and functions
2. `escrow_payment_system.sql` - Creates payment milestone system (if not already run)

### Key Services

#### RefundService (`lib/services/refund_service.dart`)

Main service for calculating and processing refunds:

```dart
// Calculate refund for a booking
final refundService = RefundService(supabase);
final calculation = await refundService.calculateRefund(
  bookingId: bookingId,
  cancellationDate: DateTime.now(),
  isVendorCancellation: false,
);

// Process refund
await refundService.processRefund(
  bookingId: bookingId,
  calculation: calculation,
  cancelledBy: 'customer',
);
```

#### BookingService Updates

The `BookingService` now includes refund-aware cancellation:

```dart
// Cancel with refund calculation
final result = await bookingService.cancelBookingWithRefund(
  bookingId: bookingId,
  isVendorCancellation: false,
);

// Get refund preview before cancelling
final preview = await bookingService.getRefundPreview(
  bookingId: bookingId,
);
```

### Category Mapping

Vendor categories are automatically mapped to refund policy categories:

- **Food & Catering:** Categories containing "catering", "food", "kitchen"
- **Venues:** Categories containing "venue", "hall", "banquet", "farmhouse", "garden"
- **DJs/Musicians:** Categories containing "dj", "music", "band", "singer", "performer", "anchor"
- **Decorators:** Categories containing "decor", "decoration", "flower", "lighting", "stage", "tent", "chair", "sound", "generator", "essential"

### Refund Flow

1. **Customer/Vendor initiates cancellation**
2. **System calculates refund** based on:
   - Category type
   - Days before event
   - Payment milestones status
   - Cancellation type (customer vs vendor)
3. **Refund record created** in `refunds` table
4. **Payment milestones updated** to "refunded" status
5. **Booking status updated** to "cancelled"
6. **Vendor penalties applied** (if vendor cancellation)
7. **Refund processed** via payment gateway (admin action)

### Admin Portal Actions

Admins can:

1. **View refund requests** in `refunds` table
2. **Process refunds** via payment gateway
3. **Update refund status** to "completed" or "rejected"
4. **View vendor penalties** in `vendor_cancellation_penalties` table
5. **Manage vendor suspensions** and blacklisting

### Important Notes

1. **Platform commission and payment gateway charges are non-refundable**
2. **Direct cash or off-platform payments are strictly prohibited**
3. **All refunds go through Saral Events escrow system**
4. **Vendor penalties are automatically applied on vendor cancellations**
5. **Multi-vendor bookings calculate refunds per vendor**

## Testing

### Test Scenarios

1. **Food & Catering - Full Refund**
   - Cancel booking 10 days before event
   - Expected: 100% of advance refunded

2. **Venue - Partial Refund**
   - Cancel booking 20 days before event
   - Expected: 50% of advance refunded

3. **Vendor Cancellation**
   - Vendor cancels booking
   - Expected: 100% refund to customer, penalties applied to vendor

4. **Multi-Vendor Booking**
   - Cancel combo booking with different categories
   - Expected: Vendor-wise refund calculation

## Database Functions

### `get_refund_summary(booking_id)`

Returns refund details for a booking:

```sql
SELECT * FROM get_refund_summary('booking-uuid');
```

### `process_vendor_cancellation(booking_id, reason)`

Processes vendor cancellation with automatic refund and penalties:

```sql
SELECT * FROM process_vendor_cancellation('booking-uuid', 'Reason');
```

## Future Enhancements

1. **Automated refund processing** via payment gateway webhooks
2. **Refund notification system** for customers and vendors
3. **Refund analytics dashboard** for admin portal
4. **Partial milestone refunds** for mid-service cancellations
5. **Dispute resolution system** for refund conflicts

