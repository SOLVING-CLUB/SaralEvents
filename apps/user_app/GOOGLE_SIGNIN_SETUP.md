# Google Sign-In Setup Guide

## Current Status ✅
- ✅ Code implementation exists (`signInWithGoogleNative()` in `session.dart`)
- ✅ UI button exists in `login_screen.dart`
- ✅ `google_sign_in` package is installed
- ✅ `google-services.json` exists for Android
- ✅ Google Client ID is configured in code

## What's Missing ❌

### 1. Android Configuration

#### Missing: Google Services Plugin
The `google-services` plugin needs to be applied in `android/app/build.gradle.kts`.

**Fix:**
```kotlin
// Add this at the top of android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ADD THIS LINE
}
```

#### Missing: Google Sign-In URL Scheme in AndroidManifest.xml
Add the Google Sign-In URL scheme to handle OAuth redirects.

**Fix:** Add this inside `<application>` tag in `android/app/src/main/AndroidManifest.xml`:
```xml
<!-- Google Sign-In -->
<meta-data
    android:name="com.google.android.gms.version"
    android:value="@integer/google_play_services_version" />
```

### 2. iOS Configuration

#### Missing: Google Sign-In URL Scheme
Add the reversed client ID as a URL scheme in `Info.plist`.

**Fix:** Add this to `ios/Runner/Info.plist` inside the `<dict>` tag:
```xml
<!-- Add Google Sign-In URL Scheme -->
<key>CFBundleURLTypes</key>
<array>
    <!-- Existing saralevents scheme -->
    <dict>
        <key>CFBundleURLName</key>
        <string>com.saral.events.user</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>saralevents</string>
            <!-- ADD THIS: Reversed Client ID from GoogleService-Info.plist -->
            <!-- Format: com.googleusercontent.apps.CLIENT_ID_REVERSED -->
            <string>com.googleusercontent.apps.314736791162-8pq9o3hr42ibap3oesifibeotdamgdj2</string>
        </array>
    </dict>
</array>
```

#### Missing: GoogleService-Info.plist
You need to download this file from Firebase Console and add it to `ios/Runner/GoogleService-Info.plist`.

**Steps:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Project Settings > General
4. Under "Your apps", find iOS app (or create one)
5. Download `GoogleService-Info.plist`
6. Place it in `ios/Runner/GoogleService-Info.plist`

### 3. Supabase Configuration

#### Missing: OAuth Redirect URLs
Configure redirect URLs in Supabase Dashboard.

**Steps:**
1. Go to Supabase Dashboard > Authentication > URL Configuration
2. Add these redirect URLs:
   - **Android:** `com.saralevents.userapp://`
   - **iOS:** `saralevents://`
   - **Web:** `https://saralevents.vercel.app/auth/callback` (if applicable)

#### Missing: Google OAuth Provider Setup
Enable Google OAuth in Supabase.

**Steps:**
1. Go to Supabase Dashboard > Authentication > Providers
2. Enable "Google" provider
3. Add your Google OAuth credentials:
   - **Client ID:** `314736791162-8pq9o3hr42ibap3oesifibeotdamgdj2.apps.googleusercontent.com`
   - **Client Secret:** (Get from Google Cloud Console)

### 4. Google Cloud Console Configuration

#### Verify SHA-1 Fingerprint (Android)
Add your app's SHA-1 fingerprint to Google Cloud Console.

**Get SHA-1:**
```bash
# Debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release keystore (if you have one)
keytool -list -v -keystore android/app/key.jks -alias upload
```

**Add to Google Cloud Console:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to APIs & Services > Credentials
4. Edit your OAuth 2.0 Client ID
5. Add SHA-1 fingerprint under "Android" section

#### Verify OAuth Consent Screen
Ensure OAuth consent screen is configured:
1. Go to APIs & Services > OAuth consent screen
2. Configure app name, support email, etc.
3. Add scopes: `email`, `profile`, `openid`

### 5. Code Fixes Needed

#### Issue: Client ID Mismatch
The `serverClientId` in `session.dart` might not match the one in `build.gradle.kts`.

**Current in session.dart:**
```dart
const serverClientId = '314736791162-8pq9o3hr42ibap3oesifibeotdamgdj2.apps.googleusercontent.com';
```

**Current in build.gradle.kts:**
```kotlin
manifestPlaceholders["GOOGLE_SIGN_IN_CLIENT_ID"] = "314736791162-afldsldle2v8ddkvt7dg16co5hlgpuus.apps.googleusercontent.com"
```

**Fix:** Use the same Client ID everywhere. The `serverClientId` should be the **Web Client ID** (not Android Client ID).

## Quick Setup Checklist

- [ ] Apply `google-services` plugin in `android/app/build.gradle.kts`
- [ ] Add Google Sign-In meta-data to `AndroidManifest.xml`
- [ ] Add reversed client ID URL scheme to iOS `Info.plist`
- [ ] Download and add `GoogleService-Info.plist` to iOS project
- [ ] Configure redirect URLs in Supabase Dashboard
- [ ] Enable Google OAuth provider in Supabase
- [ ] Add SHA-1 fingerprint to Google Cloud Console
- [ ] Verify OAuth consent screen is configured
- [ ] Ensure Client IDs match across all configurations

## Testing

After completing the setup:
1. Clean and rebuild the app
2. Test Google Sign-In on Android device/emulator
3. Test Google Sign-In on iOS device/simulator
4. Verify user profile is created in Supabase after sign-in

## Troubleshooting

**Error: "Sign-in cancelled"**
- Check if Google Play Services is installed (Android)
- Verify OAuth consent screen is published

**Error: "No Google ID token received"**
- Verify Client ID matches in all places
- Check SHA-1 fingerprint is added to Google Cloud Console

**Error: "OAuth provider not enabled"**
- Enable Google provider in Supabase Dashboard

**iOS: Sign-in doesn't work**
- Verify `GoogleService-Info.plist` is added to Xcode project
- Check URL scheme is correctly configured in Info.plist
