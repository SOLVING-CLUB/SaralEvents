# Support Page Enhancements

## Summary
Enhanced support pages across all three applications (User App, Vendor App, and Admin Web) with Contact Number and Order ID fields.

## Changes Made

### 1. Database Schema Update
**File:** `apps/user_app/add_support_fields.sql`

- Added `order_id` column (UUID, nullable, references orders table)
- Added `contact_number` column (TEXT, nullable)
- Created index on `order_id` for faster lookups
- Added column comments for documentation

**To apply:** Run the SQL migration file in your Supabase database.

### 2. User App - Support Screen
**File:** `apps/user_app/lib/screens/support_screen.dart`

**Changes:**
- Added Contact Number field (pre-filled from user profile, editable)
- Added Order ID input field with UUID format validation
- Updated form submission to include `order_id` and `contact_number`
- Added `_validateOrderId()` method for UUID format validation (8-4-4-4-12 hexadecimal pattern)
- Auto-loads contact number from user profile on init

### 3. User App - Help & Support Screen
**File:** `apps/user_app/lib/screens/help_support_screen.dart`

**Changes:**
- Added Contact Number field (pre-filled from user profile, editable)
- Added Order ID input field with UUID format validation
- Updated to use `support_tickets` table directly instead of edge function
- Maps issue types to appropriate support categories
- Includes `order_id` and `contact_number` in ticket creation

### 4. Vendor App - Help & Support Screen
**File:** `saral_events_vendor_app/lib/features/help/help_support_screen.dart`

**Changes:**
- Added Contact Number field (pre-filled from vendor profile, editable)
- Added Order ID input field with UUID format validation
- Updated ticket creation to include `order_id` and `contact_number`
- Auto-loads contact number from vendor profile on init

### 5. Admin Web - Support Management Page
**File:** `apps/company_web/src/app/dashboard/support/page.tsx`

**Changes:**
- Updated `SupportTicket` interface to include `order_id` and `contact_number`
- Added Order ID column in tickets table (with clickable link to order details)
- Added Contact Number display in user information section
- Updated ticket loading query to fetch `order_id` and `contact_number`
- Enhanced search filter to include Order ID
- Added Order ID and Contact Number display in ticket details modal
- Order ID links to `/dashboard/orders/[id]` for quick access to order details

## Features

### Contact Number Field
- **Static/Configurable:** Currently loads from user/vendor profile, but can be edited manually
- **Display:** Shown in admin support view for easy contact
- **Validation:** Basic phone number format validation (minimum 10 digits)

### Order ID Field
- **Optional:** Users can optionally provide Order ID when submitting support requests
- **Validation:** UUID format validation (8-4-4-4-12 hexadecimal characters)
- **Admin Integration:** Order ID is clickable in admin view, linking directly to order details page
- **Search:** Order ID is included in search functionality

## Order ID Format Validation

Order IDs must follow UUID format:
- Pattern: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- Example: `550e8400-e29b-41d4-a716-446655440000`
- Validation regex: `^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`

## Testing Checklist

- [ ] Run database migration (`add_support_fields.sql`)
- [ ] Test User App support form with Order ID
- [ ] Test User App help & support form with Order ID
- [ ] Test Vendor App help & support form with Order ID
- [ ] Verify Order ID validation (valid and invalid formats)
- [ ] Verify Contact Number auto-loads from profile
- [ ] Verify Contact Number can be edited manually
- [ ] Test Admin support page displays Order ID
- [ ] Test Order ID link navigates to order details
- [ ] Test search functionality includes Order ID
- [ ] Verify Contact Number displays in admin view

## Future Enhancements

1. **Configurable Contact Number:** Add admin settings page to configure default support contact number
2. **Order ID Autocomplete:** Suggest user's recent orders when typing Order ID
3. **Order Details Preview:** Show order summary in support ticket modal without navigation
4. **Contact Number Formatting:** Add phone number formatting (e.g., +91 format)
