# Cart Items Implementation Plan

## Overview
Replace `booking_drafts` table with `cart_items` table that serves both as shopping cart AND pre-payment booking storage.

## Benefits
1. ✅ Single source of truth (no duplicate data)
2. ✅ Cart persists across devices (like Amazon)
3. ✅ Simpler architecture (one table instead of two)
4. ✅ Better user experience (cart syncs everywhere)

## Database Schema

```sql
-- Cart Items Table (replaces booking_drafts)
CREATE TABLE IF NOT EXISTS cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  vendor_id UUID NOT NULL REFERENCES vendor_profiles(id) ON DELETE CASCADE,
  
  -- Cart fields
  quantity INTEGER NOT NULL DEFAULT 1,
  price DECIMAL(10,2) NOT NULL,
  
  -- Booking-specific fields (can be null until checkout)
  booking_date DATE,
  booking_time TIME,
  event_date DATE,
  notes TEXT,
  
  -- Billing details (can be null until checkout)
  billing_name TEXT,
  billing_email TEXT,
  billing_phone TEXT,
  message_to_vendor TEXT,
  
  -- Status: 'active' (in cart), 'saved_for_later', 'checkout_pending', 'completed'
  status TEXT NOT NULL DEFAULT 'active' 
    CHECK (status IN ('active', 'saved_for_later', 'checkout_pending', 'completed')),
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days')
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_cart_items_user_status 
  ON cart_items(user_id, status);
CREATE INDEX IF NOT EXISTS idx_cart_items_user_active 
  ON cart_items(user_id) WHERE status IN ('active', 'saved_for_later');

-- RLS Policies
ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own cart items"
  ON cart_items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own cart items"
  ON cart_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own cart items"
  ON cart_items FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own cart items"
  ON cart_items FOR DELETE
  USING (auth.uid() = user_id);
```

## Migration Steps

### Step 1: Create cart_items table
Run the SQL schema above in Supabase.

### Step 2: Migrate existing drafts to cart_items
```sql
-- Migrate active drafts to cart_items
INSERT INTO cart_items (
  user_id, service_id, vendor_id, price,
  booking_date, booking_time, event_date, notes,
  billing_name, billing_email, billing_phone, message_to_vendor,
  status, created_at, updated_at, expires_at
)
SELECT 
  user_id, service_id, vendor_id, amount,
  booking_date, booking_time, event_date, notes,
  billing_name, billing_email, billing_phone, message_to_vendor,
  CASE 
    WHEN status = 'draft' THEN 'active'
    WHEN status = 'payment_pending' THEN 'checkout_pending'
    ELSE 'active'
  END,
  created_at, updated_at, expires_at
FROM booking_drafts
WHERE status IN ('draft', 'payment_pending')
  AND expires_at > NOW();
```

### Step 3: Update Flutter Code
1. Create `CartItemService` (similar to `BookingDraftService`)
2. Update `CheckoutState` to sync with Supabase
3. Update checkout flow to use `cart_items` instead of `booking_drafts`
4. After payment, create bookings from `cart_items` and delete them

### Step 4: Remove booking_drafts
After migration is complete and verified:
```sql
DROP TABLE booking_drafts;
```

## Implementation Details

### CartItemService Methods Needed:
- `addToCart()` - Add item to cart
- `getCartItems()` - Get user's cart (status='active')
- `getSavedForLater()` - Get saved items (status='saved_for_later')
- `updateCartItem()` - Update booking details, billing info
- `moveToSaved()` - Move item to saved_for_later
- `moveToCart()` - Move item back to cart
- `removeFromCart()` - Delete cart item
- `clearCart()` - Delete all cart items for user
- `markCheckoutPending()` - Mark items as checkout_pending before payment
- `createBookingsFromCart()` - Create bookings from cart_items after payment

### CheckoutState Updates:
- Load cart from Supabase on app start/login
- Sync every cart change (add/remove/update) to Supabase
- Auto-save billing details to cart_items
- After payment success, create bookings and clear cart

## Flow Comparison

### OLD Flow (with drafts):
1. Add to cart (in-memory) → 
2. Proceed to checkout → 
3. Save billing details → Create `booking_draft` → 
4. Payment → 
5. Create booking from draft → 
6. Mark draft as completed

### NEW Flow (with cart_items):
1. Add to cart → Save to `cart_items` (status='active') → 
2. Proceed to checkout → Update `cart_items` with billing details → 
3. Payment → Mark `cart_items` (status='checkout_pending') → 
4. Payment success → Create bookings from `cart_items` → Delete `cart_items`
5. Payment fails → Keep `cart_items` (status='active'), user can retry

## Benefits Summary

✅ **Single table** instead of two (cart_items replaces booking_drafts)  
✅ **Cross-device sync** (cart available everywhere)  
✅ **Simpler code** (one service instead of two)  
✅ **Better UX** (cart persists, no data loss)  
✅ **Cleaner architecture** (less duplication)

## Next Steps

1. Review this plan
2. Create cart_items table in Supabase
3. Implement CartItemService
4. Update CheckoutState to sync with Supabase
5. Update checkout flow
6. Test migration
7. Remove booking_drafts table
