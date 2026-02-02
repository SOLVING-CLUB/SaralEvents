# Fixing Google Sign-In Error Code 10 (DEVELOPER_ERROR) - URGENT FIX

## 🔴 THE PROBLEM FOUND:

**Your debug keystore SHA-1 is NOT in Google Cloud Console!**

- **Your Debug SHA-1**: `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
- **In GCP**: `B7:39:27:02:D0:2B:F6:DF:57:5B:A2:33:CD:F5:9A:3B:78:5F:C6:EC` (This is your release SHA-1)

**When you test on a device/emulator, you're using a DEBUG build, which uses the debug keystore. Google doesn't recognize this SHA-1, so it throws error code 10!**

## ✅ IMMEDIATE FIX:

### Step 1: Add Debug SHA-1 to Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: **saralevents-6fe20**
3. Go to **APIs & Services** → **Credentials**
4. Find your **Android OAuth 2.0 Client ID** for **User App** (package: `com.saralevents.userapp`)
5. Click **Edit** (pencil icon)
6. Under **SHA-1 certificate fingerprints**, click **+ Add fingerprint**
7. Add this SHA-1: `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
8. Click **Save**

### Step 2: Do the Same for Vendor App

1. Find your **Android OAuth 2.0 Client ID** for **Vendor App** (package: `com.saralevents.vendorapp`)
2. Click **Edit**
3. Add the same debug SHA-1: `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
4. Click **Save**

### Step 3: Wait and Test

1. **Wait 5-10 minutes** for Google's changes to propagate
2. **Clean your project:**
   ```powershell
   cd apps/user_app
   flutter clean
   ```
3. **Rebuild and test:**
   ```powershell
   flutter run
   ```

---

# Fixing Google Sign-In Error Code 10 (DEVELOPER_ERROR)

## The Problem

Error code 10 (`DEVELOPER_ERROR`) from Google Sign-In API means there's a **configuration mismatch** between your app and Google Cloud Console.

## Most Common Causes:

1. **SHA-1 Fingerprint Mismatch** (Most Likely!)
   - The SHA-1 of the keystore you're using to build the app doesn't match what's in Google Cloud Console
   - Debug builds use the debug keystore
   - Release builds use the release keystore

2. **Package Name Mismatch**
   - The package name in your app doesn't match the OAuth client in Google Cloud Console

3. **OAuth Client Not Configured**
   - The Android OAuth client doesn't exist or isn't properly set up

## Step-by-Step Fix:

### Step 1: Get Your Current Debug SHA-1

Run this command to get your debug keystore SHA-1:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Look for the line that says **SHA1:** and copy that value.

### Step 2: Compare with Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** → **Credentials**
4. Find your **Android OAuth 2.0 Client ID** for the user app
5. Check the **SHA-1 certificate fingerprint** listed there

### Step 3: Add Missing SHA-1

If the SHA-1 from Step 1 is **different** from what's in Google Cloud Console:

1. In Google Cloud Console, click **Edit** on your Android OAuth client
2. Under **SHA-1 certificate fingerprints**, click **+ Add fingerprint**
3. Paste the SHA-1 from Step 1
4. Click **Save**

### Step 4: Clean and Rebuild

After adding the SHA-1:

1. **Clean your project:**
   ```powershell
   cd apps/user_app
   flutter clean
   ```

2. **Rebuild the app:**
   ```powershell
   flutter build apk --debug
   # OR if testing on device:
   flutter run
   ```

### Step 5: Wait for Propagation

Google's changes can take **5-10 minutes** to propagate. Wait a few minutes before testing again.

## Important Notes:

### Debug vs Release Builds

- **Debug builds** use: `~/.android/debug.keystore`
- **Release builds** use: Your release keystore (e.g., `user-release-key.keystore`)

**You need to add BOTH SHA-1 fingerprints to Google Cloud Console:**
1. Debug keystore SHA-1 (for development/testing)
2. Release keystore SHA-1 (for production builds)

### How to Get Release SHA-1

If you have a release keystore:

```powershell
keytool -list -v -keystore apps\user_app\android\app\user-release-key.keystore -alias release
```

(You'll be prompted for the keystore password)

## Verification Checklist:

- [ ] Got debug SHA-1 fingerprint
- [ ] Compared with Google Cloud Console
- [ ] Added debug SHA-1 to Google Cloud Console (if different)
- [ ] Added release SHA-1 to Google Cloud Console (if using release builds)
- [ ] Cleaned and rebuilt the app
- [ ] Waited 5-10 minutes for changes to propagate
- [ ] Tested Google Sign-In again

## Still Not Working?

If it still doesn't work after adding SHA-1:

1. **Double-check package name:**
   - App package: `com.saralevents.userapp`
   - GCP OAuth client package: Should match exactly

2. **Verify OAuth client is enabled:**
   - Check that the Android OAuth client is active/enabled

3. **Check google-services.json:**
   - Verify it's in the correct location: `android/app/google-services.json`
   - Verify package name matches: `com.saralevents.userapp`

4. **Try uninstalling and reinstalling the app:**
   - Sometimes cached configurations cause issues
