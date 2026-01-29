# Location Session Logic Explanation

## What is a "Session"?

A **session** in this app means **one complete app lifecycle**:

### ✅ Fresh Session (App Completely Closed & Reopened)
- User closes the app completely (swipes away from recent apps)
- User reopens the app
- **Result:** `location_checked_this_session` is reset to `false` in `main.dart`
- **Bottom sheet WILL show** if location is off

### ❌ Same Session (App Resumed from Background)
- User presses home button (app goes to background)
- User reopens app from recent apps
- **Result:** `location_checked_this_session` remains `true` (not reset)
- **Bottom sheet WILL NOT show** (already checked)

---

## How It Works

### 1. App Startup (`main.dart`)
```dart
// Every time app starts (fresh or resumed), this runs:
await prefs.setBool('location_checked_this_session', false);
```

**Important:** This resets the flag on EVERY app start, whether fresh or resumed.

### 2. Home Screen Initialization (`home_screen.dart`)
```dart
// Checks if location was already checked this session
final hasCheckedThisSession = prefs.getBool('location_checked_this_session') ?? false;
if (hasCheckedThisSession) {
  return; // Skip check
}
```

### 3. After Location Check
```dart
// Set flag to true after checking
await prefs.setBool('location_checked_this_session', true);
```

---

## The Problem You Experienced

**Issue:** Bottom sheet didn't show even though location was off after completely closing and reopening the app.

**Possible Causes:**
1. ✅ **FIXED:** `_hasAppBeenInBackground` was being set during app startup, causing the check to be skipped
2. ✅ **FIXED:** Lifecycle observer was triggering false positives during initial startup

**Solution Applied:**
- Added `_isInitialStartup` flag to ignore lifecycle changes during first 2 seconds
- Simplified check logic to rely primarily on `location_checked_this_session` flag
- Improved debug logging to track what's happening

---

## Testing the Fix

### Test 1: Fresh App Start (Location OFF)
1. **Close app completely** (swipe away from recent apps)
2. **Turn OFF location** in device settings
3. **Reopen app**
4. **Expected:** Bottom sheet should appear

### Test 2: Fresh App Start (Location ON, Permission Granted)
1. **Close app completely**
2. **Turn ON location** and grant permission
3. **Reopen app**
4. **Expected:** Location should be fetched automatically, no bottom sheet

### Test 3: Resume from Background
1. **Open app** (location check happens)
2. **Press home button** (app goes to background)
3. **Reopen from recent apps**
4. **Expected:** No bottom sheet (already checked this session)

---

## Debug Logs to Check

When you test, look for these logs in the console:

```
Starting location check (fresh app start)
Device location is OFF - showing bottom sheet
```

OR

```
Location already checked this session - skipping
```

If you see "Location already checked this session" on a fresh start, there's still an issue.

---

## Current Behavior

- ✅ **Fresh app start:** Always checks location (flag is reset in `main.dart`)
- ✅ **Resume from background:** Skips check (flag remains `true`)
- ✅ **Initial startup phase:** Ignores false lifecycle triggers (first 2 seconds)

---

## If Issue Persists

1. **Check debug logs** - Look for "Starting location check" message
2. **Verify flag reset** - Check if `location_checked_this_session` is being reset in `main.dart`
3. **Check timing** - The check happens 800ms after UI is ready
4. **Verify authentication** - Bottom sheet only shows if user is logged in
