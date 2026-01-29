# EXACT STEPS - What to Do Right Now

## You're on the "Create API key" screen

### Step 1: Name Your Key (Optional)
- The name "API key 3" is fine, or change it to "Maps SDK Key" if you want

### Step 2: Add Android Restrictions (DO THIS NOW)

**In the "Android restrictions" section:**

1. Click **"+ Add an item"** button (or similar button to add Android app)

2. **First entry - Debug SHA-1:**
   - **Package name field:** Type exactly: `com.saralevents.userapp`
   - **SHA-1 certificate fingerprint field:** Type exactly: `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
   - Click **"Add"** or the checkmark

3. **Second entry - Release SHA-1:**
   - Click **"+ Add an item"** button again
   - **Package name field:** Type exactly: `com.saralevents.userapp` (same as above)
   - **SHA-1 certificate fingerprint field:** Type exactly: `F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`
   - Click **"Add"** or the checkmark

**You should now see 2 Android apps listed**

### Step 3: Scroll Down to API Restrictions

1. Scroll down on the page
2. Find the **"API restrictions"** section
3. Select **"Restrict key"** (radio button)
4. Click **"Select APIs"** button

### Step 4: Select APIs

In the popup/dialog that appears:

1. Search for or find: **"Maps SDK for Android"** → Check the box ✅
2. Search for or find: **"Places API"** → Check the box ✅
3. Search for or find: **"Geocoding API"** → Check the box ✅
4. Click **"OK"** or **"Done"**

### Step 5: Create the Key

1. Scroll to the bottom of the page
2. Click **"Create"** button (or "Save" if editing)
3. **COPY THE API KEY** that appears (it will look like: `AIzaSy...`)

---

## What You Should See After Adding Android Apps

```
Android restrictions
┌─────────────────────────────────────────────────────┐
│ Package name: com.saralevents.userapp              │
│ SHA-1: 34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:... │
│ [Remove]                                           │
└─────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────┐
│ Package name: com.saralevents.userapp              │
│ SHA-1: F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:... │
│ [Remove]                                           │
└─────────────────────────────────────────────────────┘
[+ Add an item]
```

---

## Copy These Values Exactly:

**Package Name (use twice):**
```
com.saralevents.userapp
```

**Debug SHA-1 (first entry):**
```
34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37
```

**Release SHA-1 (second entry):**
```
F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04
```

---

## After Creating:

1. **Copy the API key** that Google gives you
2. **Tell me the API key** and I'll update your app files automatically!
