# Android App Signing Setup

## SHA1 Fingerprint
Your app should be signed with a keystore that has this SHA1 fingerprint:
```
42:C0:05:DB:3D:92:D7:39:A5:DF:25:F8:FD:72:50:4E:FE:C0:A9:1F
```

## Setup Instructions

### 1. Verify Your Keystore SHA1
If you already have a keystore file, verify its SHA1 fingerprint:
```bash
keytool -list -v -keystore your-release-key.keystore
```
Look for the SHA1 value in the output. It should match: `42:C0:05:DB:3D:92:D7:39:A5:DF:25:F8:FD:72:50:4E:FE:C0:A9:1F`

### 2. Create key.properties File
1. Copy the template:
   ```bash
   cp key.properties.template key.properties
   ```

2. Edit `key.properties` and fill in your keystore details:
   ```
   storePassword=your_actual_keystore_password
   keyPassword=your_actual_key_password
   keyAlias=your_actual_key_alias
   storeFile=../app/your-release-key.keystore
   ```

3. Place your keystore file in `android/app/` directory

### 3. Build Signed AAB
Once configured, build the signed AAB:
```bash
flutter build appbundle --release
```

The AAB will be located at:
```
build/app/outputs/bundle/release/app-release.aab
```

## Important Notes
- **DO NOT** commit `key.properties` or your `.keystore` file to version control
- Keep your keystore file and passwords secure
- The release build now uses the release signing config (not debug)
- If `key.properties` doesn't exist, the build will fall back to debug signing

## Troubleshooting

### If you don't have a keystore yet:
You can generate a new keystore, but note that the SHA1 will be different:
```bash
keytool -genkey -v -keystore android/app/release-key.keystore -alias release -keyalg RSA -keysize 2048 -validity 10000
```

### To verify SHA1 after building:
```bash
keytool -list -v -keystore android/app/your-release-key.keystore -alias your_key_alias
```

