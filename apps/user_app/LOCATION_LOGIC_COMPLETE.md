# Complete Location Logic - Swiggy Instamart Style

## 🎯 Overview

This document explains the complete location handling logic implemented in the user app, following Swiggy Instamart-style behavior.

---

## 📋 State Management

### Session Flags (Reset on App Start)
- `locationResolvedThisSession` - Tracks if location was resolved this session
- `permissionAskedThisSession` - Tracks if permission was asked this session

### Persistent State (Survives App Restarts)
- `lastSelectedLocationId` - ID of the last selected location
- `activeAddress` - Currently active address (saved or temporary)
- `savedAddresses` - List of saved addresses

---

## 🚀 App Launch Behavior (Cold Start)

### Step-by-Step Logic Flow

```
1️⃣ Check if user has valid last-selected location
   ├─ YES → Use it, mark resolved, DON'T show bottom sheet ✅
   └─ NO → Continue to Step 2

2️⃣ Check if location already resolved this session
   ├─ YES → Skip check, DON'T show bottom sheet ✅
   └─ NO → Continue to Step 3

3️⃣ Get location state (GPS + Permission)
   ├─ GPS: ON/OFF
   └─ Permission: granted/denied/notAsked

4️⃣ If permission granted AND GPS ON
   ├─ Attempt auto-fetch location
   ├─ If success → Save, mark resolved, DON'T show bottom sheet ✅
   └─ If fails → Show bottom sheet ❌

5️⃣ If permission denied OR GPS OFF
   └─ Show bottom sheet (non-dismissible) ❌
```

---

## 📍 Bottom Sheet Visibility Rules

### When Bottom Sheet Shows:
- ✅ Cold start (app process created)
- ✅ No valid last-selected location exists
- ✅ Location not resolved this session
- ✅ Permission denied OR GPS OFF

### When Bottom Sheet Does NOT Show:
- ❌ App resumed from background (same session)
- ❌ Valid last-selected location exists
- ❌ Location already resolved this session
- ❌ Permission granted AND GPS ON (auto-fetch succeeds)

### Bottom Sheet Properties:
- **Non-dismissible** - Cannot close by tapping outside
- **Non-draggable** - Cannot swipe down to dismiss
- **No back button** - Must select address or grant permission
- **Only closes when:**
  - User selects a saved address, OR
  - User grants permission and location is resolved

---

## 💾 Saved Address Handling

### Fetching Addresses:
- **If logged in:** Fetch from backend (Supabase)
- **If logged out:** Fetch locally stored addresses

### When Address Selected:
1. Validate delivery serviceability (if needed)
2. Set as `activeLocation` (current session)
3. Set as `sessionLocation` (persists)
4. Save `lastSelectedLocationId`
5. Persist locally
6. Close bottom sheet
7. Load storefronts/vendors

---

## 🔄 Auto Location Detection

### Logic:
- Attempts auto-detection **only once per session**
- Stores flag: `locationResolvedThisSession = true`
- If auto-detection fails → Show bottom sheet

### Conditions for Auto-Fetch:
- ✅ Permission granted
- ✅ GPS enabled
- ✅ No valid last-selected location

---

## 🔀 Session vs Background Handling

### App Session Definition:
**Session = App process created → App process destroyed**

### Behavior:
- **Backgrounded:** DO NOTHING (flags remain unchanged)
- **Foregrounded:** DO NOTHING (flags remain unchanged)
- **Cold Start:** Reset flags, check location

### Bottom Sheet Behavior:
- **NOT reappear when:**
  - App minimized and reopened
  - User switches apps
  - App resumed from recent apps

- **Reappear only when:**
  - App fully killed and relaunched
  - AND no valid location exists

---

## 🔐 Permission Re-Prompt Strategy

### Rules:
- Do NOT repeatedly ask during same session
- Store: `permissionAskedThisSession = true`
- Re-prompt only when:
  - New app session starts
  - AND no valid delivery location exists

---

## 🔍 Manual Search Flow

### Allowed Actions:
- Address search via autocomplete
- On selection:
  - Validate service availability
  - Save as session + persistent location
  - Close bottom sheet

---

## 📊 State Storage Locations

| State | Storage | Location |
|-------|---------|----------|
| `locationResolvedThisSession` | SharedPreferences | Session flag |
| `permissionAskedThisSession` | SharedPreferences | Session flag |
| `lastSelectedLocationId` | SharedPreferences | Persistent |
| `activeAddress` | AddressStorage | Persistent |
| `savedAddresses` | AddressStorage | Persistent |
| `tempLocation` | AddressStorage | Session-only |

---

## 🎬 Code Flow Example

### Scenario 1: User has saved address
```
App Start → Check lastSelectedLocationId → Found "home" → 
Load address → Display "Ramanthapur" → Done ✅
```

### Scenario 2: No address, permission granted, GPS ON
```
App Start → No lastSelectedLocationId → Check state → 
Permission granted + GPS ON → Auto-fetch → 
Save temp location → Display address → Done ✅
```

### Scenario 3: No address, permission denied
```
App Start → No lastSelectedLocationId → Check state → 
Permission denied → Show bottom sheet → 
User selects address → Save → Close sheet → Done ✅
```

### Scenario 4: App resumed from background
```
App Resume → Check _hasAppBeenInBackground → 
True → Skip location check → Use existing address → Done ✅
```

---

## 🐛 Edge Cases Handled

1. ✅ **GPS ON but permission denied** → Show bottom sheet
2. ✅ **Permission granted but GPS OFF** → Show bottom sheet
3. ✅ **User logs out mid-session** → Address persists locally
4. ✅ **App killed while bottom sheet open** → Bottom sheet reappears on restart
5. ✅ **User changes permission from settings** → Checked on next cold start
6. ✅ **Address selected but delivery not serviceable** → Address still saved, can validate later

---

## 🔧 Key Files

- `lib/core/services/location_session_manager.dart` - Session state management
- `lib/screens/home_screen.dart` - Main location check logic
- `lib/widgets/location_startup_bottom_sheet.dart` - Bottom sheet UI
- `lib/core/services/address_storage.dart` - Address persistence
- `lib/main.dart` - Session flag reset on app start

---

## ✅ Testing Checklist

- [ ] Fresh app start with saved address → No bottom sheet
- [ ] Fresh app start without address, permission granted → Auto-fetch
- [ ] Fresh app start without address, permission denied → Show bottom sheet
- [ ] Fresh app start without address, GPS OFF → Show bottom sheet
- [ ] App resumed from background → No bottom sheet
- [ ] Bottom sheet non-dismissible → Cannot close without selecting
- [ ] Address selected → Saved and displayed correctly
- [ ] Auto-fetch fails → Falls back to bottom sheet

---

## 📝 Debug Logs to Monitor

Look for these logs in console:

- `🚀 Starting location check (cold start)` - Location check started
- `✅ Valid last-selected location exists` - Using saved address
- `📍 Permission granted & GPS ON` - Attempting auto-fetch
- `📍 Permission denied OR GPS OFF` - Showing bottom sheet
- `🔄 App resumed from background` - Skipping check
- `✅ Location resolved this session` - Marked as resolved

---

## 🎯 Goal Achieved

✅ Zero unnecessary prompts  
✅ No repeated bottom sheets  
✅ No location re-asking during background/foreground  
✅ Frictionless experience identical to Swiggy Instamart
