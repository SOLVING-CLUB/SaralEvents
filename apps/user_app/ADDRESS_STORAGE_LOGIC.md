# Address Storage Logic - Detailed Explanation

## Overview
The app now distinguishes between **saved addresses** (permanent, manually saved) and **temporary locations** (session-only, automatically fetched or selected).

## Two Types of Address Storage

### 1. Saved Addresses (Permanent)
- **Stored in**: `saved_addresses_v1` key in SharedPreferences
- **When added**: Only when user explicitly saves an address
- **Persistence**: Persists across app sessions
- **Examples**:
  - User selects from saved addresses list
  - User manually adds address in profile settings
  - User selects location from location picker (manual action)

### 2. Temporary Locations (Session-Only)
- **Stored in**: `temp_loc_lat`, `temp_loc_lng`, `temp_loc_address` keys
- **When added**: Automatically fetched locations or selected locations
- **Persistence**: Cleared on app start (session-only)
- **Examples**:
  - Auto-fetched location when app starts (location ON + permission granted)
  - Location fetched when user clicks "GRANT" in bottom sheet
  - Any location that shouldn't persist to next session

## Key Methods

### `AddressStorage.setActive(AddressInfo info, {bool addToSaved = true})`
- Sets a **saved address** as active
- If `addToSaved = true` (default), adds to saved addresses list
- Clears temporary location when called
- **Use for**: Manually saved addresses

### `AddressStorage.setTemporaryLocation(AddressInfo info)`
- Sets a **temporary location** (session-only)
- Does NOT add to saved addresses list
- Clears active saved address ID
- **Use for**: Auto-fetched locations or session-only selections

### `AddressStorage.getActive()`
- **Priority order**:
  1. Saved address (if `_kActive` ID exists and found in saved list)
  2. Temporary location (if exists)
  3. Legacy location data (for backward compatibility)
- Returns `null` if no location found

### `AddressStorage.clearTemporaryLocation()`
- Clears temporary location data
- Called on app startup in `main.dart`

## Location Display on Homepage

The homepage shows location under user's name:
- **Priority**: Saved address > Temporary location > "Select location"
- **Updates**: When location changes (saved or temporary)
- **Session reset**: Temporary locations reset on app start, saved addresses persist

## Flow Examples

### Example 1: Fresh App Start (Location ON + Permission Granted)
1. App starts → `clearTemporaryLocation()` called
2. `_checkLocationAndShowBottomSheet()` runs
3. Location service ON + permission granted
4. `_fetchLocationDirectly()` called
5. Location fetched → `setTemporaryLocation()` called
6. Homepage shows fetched location
7. **Next app start**: Temporary location cleared, location check runs again

### Example 2: User Selects Saved Address
1. User opens bottom sheet or location picker
2. User selects a saved address (e.g., "Home")
3. `setActive(address, addToSaved: true)` called
4. Address set as active, temporary location cleared
5. Homepage shows saved address
6. **Next app start**: Saved address persists, homepage shows "Home"

### Example 3: User Grants Location Permission
1. User clicks "GRANT" in bottom sheet
2. Location permission granted
3. Location fetched → `setTemporaryLocation()` called
4. Homepage shows fetched location
5. **Next app start**: Temporary location cleared

### Example 4: User Manually Adds Address
1. User goes to profile → adds new address
2. Address saved to saved addresses list
3. `setActive(newAddress, addToSaved: true)` called
4. Address persists across sessions

## Important Notes

1. **Saved addresses list** is only updated when:
   - User explicitly saves an address
   - User selects from location picker (manual action)
   - User adds address in profile settings

2. **Temporary locations** are:
   - Automatically fetched locations
   - Session-only (reset on app start)
   - NOT added to saved addresses list

3. **Homepage display**:
   - Shows active location (saved or temporary)
   - Updates when location changes
   - Falls back to "Select location" if none found

4. **App startup**:
   - Temporary locations are cleared
   - Saved addresses persist
   - Location check runs (if fresh start)

## Files Modified

1. **`address_storage.dart`**:
   - Added `setTemporaryLocation()` method
   - Added `clearTemporaryLocation()` method
   - Modified `setActive()` to accept `addToSaved` parameter
   - Modified `getActive()` to prioritize saved addresses

2. **`main.dart`**:
   - Calls `clearTemporaryLocation()` on app start

3. **`home_screen.dart`**:
   - `_fetchLocationDirectly()` uses `setTemporaryLocation()`

4. **`location_startup_bottom_sheet.dart`**:
   - `_enableLocation()` uses `setTemporaryLocation()` for fetched locations
   - `_selectFromSaved()` uses `setActive()` for saved addresses
