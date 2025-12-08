# SHA1 Fingerprint Update

## Current Keystore Information

**Your Keystore SHA1:** `F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`

**Required SHA1 (from your request):** `42:C0:05:DB:3D:92:D7:39:A5:DF:25:F8:FD:72:50:4E:FE:C0:A9:1F`

**Status:** ❌ **DO NOT MATCH**

## What This Means

Your current keystore has a different SHA1 fingerprint than the one you specified. This means:

1. **If you need the specific SHA1** (`42:C0:05:DB:3D:92:D7:39:A5:DF:25:F8:FD:72:50:4E:FE:C0:A9:1F`):
   - You need to find/use the original keystore file that generated that SHA1
   - The current keystore (`release-key.keystore`) cannot produce that SHA1

2. **If you're okay with the new SHA1** (`F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`):
   - You need to update your Google services with the new SHA1
   - This includes: Firebase, Google Sign-In, Google Maps API

## Option 1: Use Current Keystore (Update Google Services)

If you want to proceed with the current keystore, you need to add the new SHA1 to:

### Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** > **Your apps**
4. Select your Android app
5. Click **Add fingerprint**
6. Add: `F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`

### Google Cloud Console (for Google Sign-In)
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** > **Credentials**
4. Find your OAuth 2.0 Client ID (Android)
5. Add the new SHA1: `F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`

### Google Maps API (if using)
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Go to **APIs & Services** > **Credentials**
3. Find your API key
4. Edit restrictions
5. Add package name: `com.saralevents.userapp`
6. Add SHA1: `F0:E2:34:8D:DC:50:CB:04:BE:EA:47:11:B8:10:71:F9:19:BC:66:04`

## Option 2: Find Original Keystore

If you need the specific SHA1, search for the original keystore:

### Search Locations:
- Previous project folders
- Backup locations
- Team member's computers
- Cloud storage (Google Drive, OneDrive, etc.)
- Version control (if accidentally committed)

### Verify Keystore SHA1:
```bash
keytool -list -v -keystore path/to/keystore.keystore -alias your_alias
```

Look for SHA1: `42:C0:05:DB:3D:92:D7:39:A5:DF:25:F8:FD:72:50:4E:FE:C0:A9:1F`

## Recommendation

**For a new app:** Use the current keystore and update Google services with the new SHA1.

**For an existing app on Play Store:** You MUST use the original keystore with the matching SHA1, otherwise you cannot update the app.

## Next Steps

1. **Decide which option** you want to proceed with
2. **If using current keystore:** Update Google services with new SHA1
3. **If need original keystore:** Search for it or contact your team
4. **Build AAB:** Once configured, run `flutter build appbundle --release`

