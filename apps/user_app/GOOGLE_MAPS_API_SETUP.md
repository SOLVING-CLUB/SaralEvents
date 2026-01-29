# Google Maps SDK & Places API Setup Guide

## ✅ Step 1: Get Your SHA-1 Fingerprint

You need **TWO** SHA-1 fingerprints:
1. **Debug SHA-1** (for development/testing)
2. **Release SHA-1** (for production builds)

### Get Debug SHA-1 Fingerprint

**Windows PowerShell:**
```powershell
cd apps/user_app/android
.\gradlew signingReport
```

**Or using keytool directly:**
```powershell
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Look for the line that says **SHA1:** and copy that value.

### Get Release SHA-1 Fingerprint

**If you have a release keystore:**
```powershell
keytool -list -v -keystore android/app/release-key.keystore -alias release
```

**If you don't have a release keystore yet:**
- For now, use the debug SHA-1
- You'll add the release SHA-1 later when you create the release keystore

---

## ✅ Step 2: Configure API Key Restrictions in Google Cloud Console

### 2.1 Navigate to API Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** > **Credentials**
4. Find your API key: `AIzaSyBdMMV-ceWqcoVKE_8bzMS50VARGEqT5zI`
5. Click **Edit** (pencil icon)

### 2.2 Set Application Restrictions

1. Under **Application restrictions**, select **Android apps**
2. Click **+ Add an item**
3. Enter:
   - **Package name**: `com.saralevents.userapp`
   - **SHA-1 certificate fingerprint**: Paste your **debug SHA-1** from Step 1
4. Click **+ Add an item** again to add release SHA-1 (if you have it)
5. Click **Save**

### 2.3 Set API Restrictions

1. Under **API restrictions**, select **Restrict key**
2. Check these APIs:
   - ✅ **Maps SDK for Android**
   - ✅ **Places API**
   - ✅ **Geocoding API** (for reverse geocoding addresses)
3. Click **Save**

---

## ✅ Step 3: Verify API Key Works

After saving, wait **1-2 minutes** for changes to propagate, then test:

1. Build and run your Android app
2. Navigate to the location picker screen
3. Check if:
   - ✅ Map loads without errors
   - ✅ Location search/autocomplete works
   - ✅ Current location button works

---

## 🔍 Troubleshooting

### If Maps Don't Load:

1. **Check API key restrictions:**
   - Ensure package name matches exactly: `com.saralevents.userapp`
   - Ensure SHA-1 matches your debug keystore
   - Ensure Maps SDK for Android is enabled

2. **Check Logcat for errors:**
   ```powershell
   flutter run
   # Look for errors like "API key not valid" or "This API key is not authorized"
   ```

3. **Verify API key in AndroidManifest.xml:**
   - Check that the meta-data tag is present
   - Verify the API key value matches your GCP key

### If Places Search Doesn't Work:

1. **Check Places API is enabled:**
   - Go to APIs & Services > Library
   - Search for "Places API"
   - Ensure it's enabled

2. **Check API restrictions:**
   - Ensure Places API is checked in API restrictions
   - Ensure the same SHA-1 is added

---

## 📝 Notes

- **Debug vs Release:** You'll need to add BOTH SHA-1 fingerprints if you plan to release the app
- **API Key Security:** Never commit API keys to public repositories
- **Quotas:** Free tier includes $200/month credit for Maps and Places API usage

---

## ✅ Your SHA-1 Fingerprints

**Debug SHA-1** (for development/testing):
```
34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37
```

**Release SHA-1** (for production builds):
```
F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04
```

**Package Name:**
```
com.saralevents.userapp
```

---

## ✅ Step-by-Step GCP Console Configuration

### Step 1: Navigate to API Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (the one where you enabled Maps SDK and Places API)
3. In the left sidebar, click **APIs & Services** > **Credentials**
4. Find your API key: `AIzaSyBdMMV-ceWqcoVKE_8bzMS50VARGEqT5zI`
5. Click the **pencil icon** (Edit) next to the API key

### Step 2: Configure Application Restrictions

1. Under **Application restrictions**, select **Android apps**
2. Click **+ Add an item** button
3. Enter:
   - **Package name**: `com.saralevents.userapp`
   - **SHA-1 certificate fingerprint**: `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
4. Click **+ Add an item** again to add the release SHA-1:
   - **Package name**: `com.saralevents.userapp`
   - **SHA-1 certificate fingerprint**: `F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`
5. You should now see **2 Android apps** listed
6. Click **Save** (at the bottom)

### Step 3: Configure API Restrictions

1. Under **API restrictions**, select **Restrict key**
2. Click **Select APIs**
3. Check these APIs:
   - ✅ **Maps SDK for Android**
   - ✅ **Places API**
   - ✅ **Geocoding API** (for reverse geocoding addresses)
4. Click **Save**

### Step 4: Wait and Test

1. **Wait 1-2 minutes** for changes to propagate
2. Build and run your Android app:
   ```powershell
   cd apps/user_app
   flutter run
   ```
3. Navigate to the location picker screen
4. Verify:
   - ✅ Map loads without errors
   - ✅ Location search/autocomplete works
   - ✅ Current location button works

---

## 🔍 Visual Guide

### Application Restrictions Section:
```
Application restrictions: Android apps
┌─────────────────────────────────────────────┐
│ Package name: com.saralevents.userapp      │
│ SHA-1: 34:C6:9D:08:67:8B:BE:41:42:9D:...  │
│ [+ Add an item]                            │
└─────────────────────────────────────────────┘
```

### API Restrictions Section:
```
API restrictions: Restrict key
┌─────────────────────────────────────────────┐
│ ☑ Maps SDK for Android                      │
│ ☑ Places API                                │
│ ☑ Geocoding API                             │
└─────────────────────────────────────────────┘
```

---

## ✅ Verification Checklist

After configuring, verify:

- [ ] Debug SHA-1 added: `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
- [ ] Release SHA-1 added: `F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`
- [ ] Package name matches: `com.saralevents.userapp`
- [ ] Maps SDK for Android is checked
- [ ] Places API is checked
- [ ] Geocoding API is checked
- [ ] Changes saved successfully
