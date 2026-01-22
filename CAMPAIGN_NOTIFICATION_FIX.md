# Campaign Notification Fix

## Issues Fixed

### 1. ❌ Missing `appTypes` Parameter
**Problem:** Campaign notifications were sent without `appTypes`, causing notifications to go to ALL apps (both user_app and vendor_app).

**Fix:** Added `appTypes` parameter based on target audience:
- `all_users` → `appTypes: ['user_app']`
- `all_vendors` → `appTypes: ['vendor_app']`
- `specific_users` → Determines app type per user (vendor_app or user_app)

### 2. ❌ Duplicate Notifications
**Problem:** Notifications were being sent multiple times, causing duplicates.

**Fixes Applied:**
- Added deduplication: `const uniqueUserIds = [...new Set(targetUserIds)]`
- Added status check to prevent duplicate sends: Check if campaign status is 'sent' or 'sending'
- Set status to 'sending' before sending to prevent concurrent sends
- Added sending guard to prevent multiple simultaneous sends

## Changes Made

### File: `apps/company_web/src/app/dashboard/campaigns/page.tsx`

1. **Added appTypes logic:**
   ```typescript
   let appTypes: string[] = []
   const userAppTypes = new Map<string, string[]>()
   
   if (campaign.target_audience === 'all_users') {
     appTypes = ['user_app']
   } else if (campaign.target_audience === 'all_vendors') {
     appTypes = ['vendor_app']
   } else if (campaign.target_audience === 'specific_users') {
     // Determine app type per user
   }
   ```

2. **Added appTypes to Edge Function call:**
   ```typescript
   appTypes: userSpecificAppTypes, // CRITICAL: Filter by app_type
   ```

3. **Added deduplication:**
   ```typescript
   const uniqueUserIds = [...new Set(targetUserIds)]
   ```

4. **Added duplicate send prevention:**
   ```typescript
   if (campaign.status === 'sent' || campaign.status === 'sending') {
     return // Skip duplicate send
   }
   ```

## Testing

After these fixes:
- ✅ Vendor campaigns → Only vendor app receives notifications
- ✅ User campaigns → Only user app receives notifications
- ✅ No duplicate notifications
- ✅ No cross-app leakage

## Verification

To verify the fix works:
1. Send a campaign to "all_vendors"
2. Check vendor app - should receive notification
3. Check user app - should NOT receive notification
4. Verify no duplicates appear
