# Google Play App Signing - Changing Upload Key

## Can You Change the Signing Key?

**YES, but only if Google Play App Signing is enabled!**

## Two Scenarios:

### ✅ Scenario 1: Google Play App Signing ENABLED (Recommended)

If your app uses **Google Play App Signing** (default for new apps):
- Google manages the **app signing key** (the one users see)
- You use an **upload key** to sign your AAB/APK
- **You CAN reset/change your upload key** if you lose it!

**How to check:**
1. Go to Google Play Console
2. Select your app
3. Go to **Release** > **Setup** > **App signing**
4. Look for "Google Play App Signing" status

**If enabled, you can:**
1. Go to **Release** > **Setup** > **App signing**
2. Click **Request upload key reset**
3. Follow the process to upload a new upload key certificate
4. Google will verify and accept the new key
5. You can then sign future releases with your new keystore

### ❌ Scenario 2: Google Play App Signing DISABLED (Legacy)

If your app does NOT use Google Play App Signing:
- You must use the **exact same signing key** for all updates
- **You CANNOT change it** - it's permanent
- If you lose it, you cannot update your app
- You'd need to create a new app listing

## How to Enable Google Play App Signing (If Not Enabled)

**Note:** This is usually only possible for new apps or during initial setup.

1. Go to Play Console > Your App
2. **Release** > **Setup** > **App signing**
3. If you see an option to "Opt in to Google Play App Signing", you can enable it
4. This requires uploading your current signing key to Google
5. After that, Google manages it and you can use any upload key

## Steps to Reset Upload Key (If App Signing is Enabled)

### Step 1: Generate a New Upload Key Certificate
```bash
# Create a new keystore (if you don't have one)
keytool -genkey -v -keystore upload-key.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000

# Export the certificate
keytool -export -rfc -keystore upload-key.keystore -alias upload -file upload_certificate.pem
```

### Step 2: Request Upload Key Reset in Play Console
1. Go to **Play Console** > Your App
2. **Release** > **Setup** > **App signing**
3. Click **Request upload key reset**
4. Follow the instructions
5. Upload your new certificate (`upload_certificate.pem`)

### Step 3: Wait for Approval
- Google will review your request (usually takes a few hours to days)
- You'll receive an email when approved

### Step 4: Update key.properties
Once approved, update your `key.properties` to use the new upload keystore:
```properties
storePassword=your_password
keyPassword=your_password
keyAlias=upload
storeFile=app/upload-key.keystore
```

### Step 5: Build and Upload
```bash
flutter build appbundle --release
```
Then upload the new AAB to Play Console.

## Important Notes

⚠️ **If Google Play App Signing is NOT enabled:**
- You MUST find the original keystore
- There's no way to change it
- Consider this a critical security issue

✅ **If Google Play App Signing IS enabled:**
- You can reset the upload key
- Google manages the app signing key
- This is the recommended approach

## Check Your Status Now

1. **Log into Google Play Console**
2. **Select your app**
3. **Go to:** Release > Setup > App signing
4. **Look for:** "Google Play App Signing" status
5. **Report back:** Is it enabled or disabled?

This will determine your next steps!

