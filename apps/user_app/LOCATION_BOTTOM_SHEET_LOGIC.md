# Location Bottom Sheet Logic - Detailed Explanation

## Overview
The location bottom sheet appears at app startup when device location is OFF or permission is not granted. It follows Swiggy Instamart's behavior: only shows on **fresh app start**, not when resuming from recent apps.

## Implementation Details

### 1. App Lifecycle Tracking
- Uses `WidgetsBindingObserver` to track app lifecycle state
- Tracks `_hasAppBeenInBackground` flag:
  - `false` = Fresh app start (app was killed and restarted)
  - `true` = App resumed from background (app was in recent apps)

### 2. Session Flag (`location_checked_this_session`)
- Stored in `SharedPreferences`
- Reset to `false` in `main.dart` on every app startup
- Set to `true` after location check completes
- Prevents multiple checks during the same app session

### 3. Location Check Flow

#### Step 1: Check if App Resumed from Background
```dart
if (_hasAppBeenInBackground) {
  return; // Skip - app was resumed, location already fetched
}
```

#### Step 2: Check Session Flag
```dart
if (hasCheckedThisSession) {
  return; // Already checked in this session
}
```

#### Step 3: Check User Authentication
```dart
if (user == null) {
  return; // User not logged in
}
```

#### Step 4: Check Device Location Service Status

**Case A: Device Location is OFF**
- Show bottom sheet (non-dismissible)
- User must select from saved addresses or grant permission

**Case B: Device Location is ON + Permission Granted**
- Automatically fetch current location
- Save to `AddressStorage` and `SharedPreferences`
- Update UI with fetched address

**Case C: Device Location is ON + Permission Not Granted**
- Show bottom sheet (non-dismissible)
- User can grant permission or select from saved addresses

## Conditions Summary

### Bottom Sheet Shows When:
✅ Fresh app start (not resumed from background)  
✅ User is authenticated  
✅ Device location is OFF **OR** permission not granted  
✅ Not already checked in this session  

### Bottom Sheet Does NOT Show When:
❌ App resumed from recent apps (`_hasAppBeenInBackground = true`)  
❌ Already checked in this session  
❌ User not authenticated  
❌ Device location is ON and permission is granted (auto-fetches instead)  

### Auto-Fetch Location When:
✅ Fresh app start  
✅ User authenticated  
✅ Device location is ON  
✅ Permission already granted  

## Key Files

1. **`main.dart`**: Resets `location_checked_this_session` to `false` on app startup
2. **`home_screen.dart`**: Implements location check logic with lifecycle tracking
3. **`location_startup_bottom_sheet.dart`**: UI for location selection

## Testing Scenarios

### Scenario 1: Fresh App Start (Location OFF)
1. Kill app completely
2. Open app
3. **Expected**: Bottom sheet appears immediately (non-dismissible)

### Scenario 2: Fresh App Start (Location ON + Permission Granted)
1. Kill app completely
2. Open app
3. **Expected**: Location fetched automatically, no bottom sheet

### Scenario 3: App Resume from Recent Apps
1. Open app (location fetched)
2. Press home button (app goes to background)
3. Open app from recent apps
4. **Expected**: No bottom sheet, uses previously fetched location

### Scenario 4: App Resume (Location Turned OFF)
1. Open app (location fetched)
2. Turn off device location in settings
3. Press home button
4. Open app from recent apps
5. **Expected**: No bottom sheet (uses saved location), but location won't update

## Debug Logs

The implementation includes debug prints:
- `'App resumed from background - skipping location check'`
- `'Location already checked this session - skipping'`
- `'Device location is OFF - showing bottom sheet'`
- `'Location ON and permission granted - fetching location automatically'`
- `'Location ON but permission not granted - showing bottom sheet'`

Check Flutter console for these messages to debug location check behavior.
