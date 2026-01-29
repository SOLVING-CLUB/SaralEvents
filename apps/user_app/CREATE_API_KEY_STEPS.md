# Step-by-Step: Create Google Maps API Key

## Step 1: Navigate to Credentials Page

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Make sure you're in the **"SaralEvents"** project (check top bar)
3. In the left sidebar, click **"APIs & Services"**
4. Click **"Credentials"** (should be highlighted)

You should now see:
- API Keys section (with your existing Firebase keys)
- OAuth 2.0 Client IDs section
- Service Accounts section

---

## Step 2: Create New API Key

1. At the top of the page, find the **"+ Create credentials"** button
2. Click the **dropdown arrow** next to it (▼)
3. Select **"API key"** from the dropdown menu

**What happens:**
- A new API key will be created instantly
- A popup/dialog will appear showing your new API key
- **IMPORTANT:** Copy this key immediately! It looks like: `AIzaSy...` (long string)

---

## Step 3: Copy and Save the Key

1. In the popup, you'll see your new API key
2. Click the **copy icon** (📋) next to the key to copy it
3. **Save it somewhere safe** (you'll need it in a moment)
4. Click **"Close"** or **"Restrict key"** button

**Note:** If you clicked "Close", don't worry - you can edit it next.

---

## Step 4: Edit the API Key (Configure Restrictions)

1. Find your newly created API key in the API Keys table
2. Click the **pencil icon** (✏️) in the "Actions" column to edit it

**You'll see two sections:**
- **Application restrictions** (at the top)
- **API restrictions** (below)

---

## Step 5: Configure Application Restrictions

### 5.1 Select Android Apps

1. Under **"Application restrictions"**, click the dropdown
2. Select **"Android apps"**

### 5.2 Add Debug SHA-1

1. Click **"+ Add an item"** button
2. Enter:
   - **Package name**: `com.saralevents.userapp`
   - **SHA-1 certificate fingerprint**: `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
3. The item will appear in the list

### 5.3 Add Release SHA-1

1. Click **"+ Add an item"** button again
2. Enter:
   - **Package name**: `com.saralevents.userapp`
   - **SHA-1 certificate fingerprint**: `F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`
3. You should now see **2 items** in the list

**Visual Check:**
```
Application restrictions: Android apps
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

## Step 6: Configure API Restrictions

### 6.1 Select Restrict Key

1. Under **"API restrictions"**, select **"Restrict key"** (radio button)
2. Click **"Select APIs"** button

### 6.2 Select Required APIs

A dialog will open showing all available APIs. Check **ONLY** these three:

- ✅ **Maps SDK for Android**
- ✅ **Places API**  
- ✅ **Geocoding API**

**How to find them:**
- Use the search box at the top to search for each API
- Or scroll through the list

### 6.3 Confirm Selection

1. After checking all three APIs, click **"OK"** button
2. You should see: **"3 APIs"** listed under API restrictions

**Visual Check:**
```
API restrictions: Restrict key
┌─────────────────────────────────────────────┐
│ Maps SDK for Android                        │
│ Places API                                  │
│ Geocoding API                               │
│ [Select APIs]                               │
└─────────────────────────────────────────────┘
```

---

## Step 7: Save Configuration

1. Scroll to the bottom of the page
2. Click the **"Save"** button
3. Wait for confirmation message (usually "Key saved successfully")

**Important:** Changes may take **1-2 minutes** to propagate.

---

## Step 8: Update Your App Files

After saving, you need to update your app with the new API key:

### Files to Update:

1. **`android/app/src/main/AndroidManifest.xml`**
   - Line ~101: Update the `android:value` with your new API key

2. **`lib/screens/map_location_picker.dart`**
   - Line ~39: Update the `FlutterGooglePlacesSdk()` parameter with your new API key

---

## Step 9: Test Your App

1. Wait 1-2 minutes after saving
2. Build and run your app:
   ```powershell
   cd apps/user_app
   flutter run
   ```
3. Navigate to the location picker screen
4. Verify:
   - ✅ Map loads without errors
   - ✅ Location search works
   - ✅ Current location button works

---

## Quick Reference

**Your SHA-1 Fingerprints:**
- Debug: `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
- Release: `F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`

**Package Name:** `com.saralevents.userapp`

**Required APIs:**
- Maps SDK for Android
- Places API
- Geocoding API

---

## Troubleshooting

### If you can't find "API key" option:
- Make sure you're in the correct project (SaralEvents)
- Check that you have proper permissions

### If APIs don't appear in the list:
- Go to **APIs & Services** > **Library**
- Search for each API and make sure they're **enabled**
- Then come back to Credentials

### If map doesn't load after setup:
- Wait 2-3 minutes for changes to propagate
- Check Logcat for error messages
- Verify API key is correctly added to AndroidManifest.xml

---

## Next Steps After Creating Key

Once you have your new API key, tell me:
1. **The new API key value** (so I can update your app files)
2. **Confirmation that restrictions are saved**

Then I'll update your code files automatically! 🚀
