# Refund Admin Workflow

## Overview

Refunds require **explicit admin approval** before they can be completed. When a refund is initiated (by customer or vendor), it is created with status `pending` and must be reviewed and released by an admin in the Admin Portal.

## Workflow

### 1. Refund Initiation
- Customer or vendor cancels a booking
- System calculates refund amount based on refund policy
- Refund record is created with:
  - `status`: `'pending'`
  - `refund_amount`: Calculated refundable amount
  - `non_refundable_amount`: Amount that cannot be refunded
  - `cancelled_by`: `'customer'` or `'vendor'`
  - `reason`: Cancellation reason
- Payment milestones are marked as `'refunded'`
- Booking status is updated to `'cancelled'`
- **Notification sent to user**: "Refund Initiated"

### 2. Admin Review (Admin Portal)
- Admin navigates to **Refunds** section in Admin Portal
- Views all pending refunds
- Can see:
  - Refund ID
  - Booking details
  - Service name
  - Vendor name
  - Refund amount
  - Cancellation reason
  - Who cancelled (customer/vendor)

### 3. Admin Actions

#### Release Refund (Approve)
- Admin clicks **"Release Refund"** button
- Confirmation dialog appears
- On confirmation:
  - Refund status changes to `'completed'`
  - `processed_at` is set to current timestamp
  - `processed_by` is set to admin user ID
  - `updated_at` is updated
- **Notification sent to user**: "Refund Completed - Amount credited to your account"

#### Reject Refund
- Admin clicks **"Reject Refund"** button
- Refund status changes to `'rejected'`
- Admin can add notes explaining rejection
- User is notified of rejection

## Important Notes

1. **No Auto-Completion**: Refunds are NEVER automatically completed. They always require admin approval.

2. **Status Flow**:
   - `pending` → Admin reviews
   - `pending` → `completed` (Admin releases)
   - `pending` → `rejected` (Admin rejects)
   - `pending` → `processing` (Optional intermediate state)

3. **Admin Tracking**: 
   - `processed_by` field tracks which admin released the refund
   - `processed_at` field tracks when refund was released

4. **Notifications**:
   - User receives notification when refund is initiated
   - User receives notification when refund is completed (after admin release)
   - User receives notification if refund is rejected

## Database Schema

```sql
CREATE TABLE refunds (
  id UUID PRIMARY KEY,
  booking_id UUID NOT NULL,
  cancelled_by TEXT NOT NULL, -- 'customer' or 'vendor'
  refund_amount DECIMAL(10, 2) NOT NULL,
  non_refundable_amount DECIMAL(10, 2) NOT NULL,
  refund_percentage DECIMAL(5, 2) NOT NULL,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed', 'rejected'
  admin_notes TEXT,
  processed_at TIMESTAMPTZ, -- Set when admin releases refund
  processed_by UUID, -- Admin user ID who released the refund
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Admin Portal Features

### Refund Management Page
- **Location**: `/dashboard/refunds`
- **Features**:
  - View all refunds (pending, processing, completed, rejected)
  - Filter by status
  - Search by refund ID, booking ID, or service name
  - View refund details in modal
  - Release refund (changes status to `completed`)
  - Reject refund (changes status to `rejected`)
  - See statistics (total, pending, processing, completed amounts)

### Refund Details Modal
- Shows complete refund information
- Displays booking details
- Shows refund breakdown
- Admin can:
  - Release refund (if pending)
  - Reject refund (if pending)
  - Add admin notes
  - View processing history

## Security

- Only authenticated admin users can update refund status
- `processed_by` field ensures accountability
- All refund status changes are logged with timestamps

## Testing

To test the refund workflow:

1. **Create a refund** (via booking cancellation)
2. **Verify status is 'pending'**
3. **Login as admin** in Admin Portal
4. **Navigate to Refunds** section
5. **View pending refund**
6. **Click "Release Refund"**
7. **Verify**:
   - Status changes to `completed`
   - `processed_at` is set
   - `processed_by` is set to admin user ID
   - User receives completion notification
