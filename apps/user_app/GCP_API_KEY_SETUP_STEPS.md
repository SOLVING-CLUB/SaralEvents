# GCP API Key Setup - Step by Step

## Option A: Use Existing Firebase Key (If it matches)

If the "Android key (auto created by Firebase)" matches your hardcoded key:

1. Click the **pencil icon** (Edit) next to "Android key (auto created by Firebase)"
2. Configure as shown in the main guide

## Option B: Create New API Key for Maps

### Step 1: Create the API Key

1. In the Credentials page, click **"+ Create credentials"** dropdown
2. Select **"API key"**
3. A new API key will be created
4. **Copy the key** (you'll need it)

### Step 2: Configure the New Key

1. Click the **pencil icon** (Edit) next to your new API key
2. **Name it**: "Maps SDK & Places API Key" (optional but recommended)
3. Configure restrictions as shown below

### Step 3: Application Restrictions

1. Under **Application restrictions**, select **"Android apps"**
2. Click **"+ Add an item"**
3. Enter:
   - **Package name**: `com.saralevents.userapp`
   - **SHA-1 certificate fingerprint**: `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
4. Click **"+ Add an item"** again
5. Enter:
   - **Package name**: `com.saralevents.userapp`
   - **SHA-1 certificate fingerprint**: `F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`
6. You should see **2 Android apps** listed

### Step 4: API Restrictions

1. Under **API restrictions**, select **"Restrict key"**
2. Click **"Select APIs"**
3. Check ONLY these APIs:
   - ✅ **Maps SDK for Android**
   - ✅ **Places API**
   - ✅ **Geocoding API**
4. Click **"OK"**

### Step 5: Save

1. Click **"Save"** at the bottom
2. Wait 1-2 minutes for changes to propagate

### Step 6: Update Your App

After creating/identifying the correct key, update these files:

1. **AndroidManifest.xml** - Update the API key value
2. **map_location_picker.dart** - Update the Places SDK key

---

## Quick Reference

**Debug SHA-1:** `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
**Release SHA-1:** `F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`
**Package Name:** `com.saralevents.userapp`
