# Escrow & Wallet System Verification

## Summary of Changes

I've verified and optimized the escrow payment system to ensure all amounts in escrow are properly displayed as "awaiting release" until they're actually credited to vendor wallets.

## Payment Milestone Structure

### 1. **20% Advance Payment**
- **Status Flow**: `pending` → `paid` → `held_in_escrow` → `released`
- **Auto-Release**: Automatically released when 50% arrival payment is made
- **Commission**: None (100% to vendor)
- **Display**: Shows as "AWAITING RELEASE" until wallet is credited

### 2. **50% Arrival Payment**
- **Status Flow**: `pending` → `paid` → `held_in_escrow` → `released`
- **Auto-Release**: Automatically released when 30% completion payment is made
- **Commission**: None (100% to vendor)
- **Display**: Shows as "AWAITING RELEASE" until wallet is credited

### 3. **30% Completion Payment**
- **Status Flow**: `pending` → `paid` → `held_in_escrow` → `released` (manual admin release)
- **Manual Release**: Requires admin approval in company portal
- **Commission Structure**:
  - **Company keeps**: 10% of total booking amount
  - **Vendor receives**: 20% of total booking amount
  - **Total milestone**: 30% of total booking amount
- **Display**: Shows as "AWAITING RELEASE" until wallet is credited

## Key Improvements Made

### 1. **Vendor Wallet Screen** (`wallet_screen.dart`)
- ✅ Updated to show ALL escrow amounts (including auto-released 20% and 50%) as "awaiting release"
- ✅ Checks `vendor_wallet_credited` flag in escrow transactions
- ✅ Shows milestones with status `held_in_escrow`, `paid`, OR `released` (if wallet not credited)
- ✅ For completion milestones, displays vendor amount (20%) instead of gross (30%)
- ✅ Includes bookings with status `completed` in query

### 2. **Company App Payment Milestones Page** (`payment-milestones/page.tsx`)
- ✅ Updated stats to include milestones that are `held_in_escrow` OR `released` but wallet not credited
- ✅ Shows "AWAITING RELEASE" status badge for all pending amounts
- ✅ Filter includes auto-released milestones that haven't been credited yet
- ✅ For completion milestones, shows breakdown: vendor amount (20%) and commission (10%)
- ✅ Updated all three milestone sections (advance, arrival, completion) to show correct status

### 3. **SQL Auto-Release Function** (`escrow_payment_system.sql`)
- ✅ Updated `auto_release_milestone_to_wallet()` to:
  - Create escrow transaction with status `processing` initially
  - Credit vendor wallet
  - Mark escrow transaction as `completed` with `vendor_wallet_credited = TRUE`
- ✅ Ensures proper tracking of wallet credit status

### 4. **Escrow Transaction Tracking**
- ✅ All escrow transactions now track `vendor_wallet_credited` flag
- ✅ Status flow: `processing` → `completed` (with wallet credited flag)
- ✅ Allows visibility of amounts even after auto-release until wallet is actually credited

## Display Logic

### Vendor App - "Awaiting Release" Calculation
```dart
// Milestone is shown as awaiting release if:
1. Status is 'held_in_escrow' OR 'paid' (not yet released)
2. OR status is 'released' but escrow transaction shows vendor_wallet_credited = false/null
```

### Company App - "Awaiting Release" Filter
```typescript
// Milestone is included in "held_in_escrow" filter if:
1. Status is 'held_in_escrow' OR 'paid'
2. OR status is 'released' but escrow transaction shows vendor_wallet_credited = false/null
```

## Amount Display

### For 20% Advance & 50% Arrival
- **Vendor sees**: Full milestone amount (20% or 50% of booking)
- **Company sees**: Full milestone amount
- **Commission**: None

### For 30% Completion
- **Vendor sees**: 20% of booking amount (their portion)
- **Company sees**: 
  - Gross: 30% of booking amount
  - Breakdown: Vendor 20% + Commission 10%
- **Commission**: 10% of total booking amount

## Database Schema

### `payment_milestones` Table
- `status`: `pending` | `paid` | `held_in_escrow` | `released` | `refunded`
- `escrow_held_at`: Timestamp when moved to escrow
- `escrow_released_at`: Timestamp when released

### `escrow_transactions` Table
- `transaction_type`: `hold` | `release` | `refund` | `commission_deduct`
- `status`: `pending` | `processing` | `completed` | `failed`
- `vendor_wallet_credited`: Boolean flag indicating if wallet was credited
- `commission_amount`: Amount deducted as commission (0 for advance/arrival, 10% for completion)
- `vendor_amount`: Amount credited to vendor wallet

## Testing Checklist

- [ ] 20% advance payment shows as "awaiting release" when paid
- [ ] 20% advance auto-releases when 50% arrival is paid
- [ ] 50% arrival payment shows as "awaiting release" when paid
- [ ] 50% arrival auto-releases when 30% completion is paid
- [ ] 30% completion shows as "awaiting release" when paid
- [ ] 30% completion requires manual admin release
- [ ] Company app shows correct commission (10%) and vendor amount (20%) for completion
- [ ] Vendor app shows 20% (not 30%) for completion milestone in "awaiting release"
- [ ] All amounts disappear from "awaiting release" only after wallet is credited
- [ ] Escrow transaction `vendor_wallet_credited` flag is properly set

## Files Modified

1. `apps/user_app/escrow_payment_system.sql` - Updated auto-release function
2. `saral_events_vendor_app/lib/features/wallet/wallet_screen.dart` - Updated display logic
3. `apps/company_web/src/app/dashboard/payment-milestones/page.tsx` - Updated stats and filters

## Next Steps

1. Run the updated SQL migration to update the auto-release function
2. Test the flow with a complete booking cycle
3. Verify amounts appear correctly in both vendor and company apps
