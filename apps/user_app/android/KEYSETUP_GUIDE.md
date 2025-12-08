# Keystore Setup Guide

## Important Note About SHA1 Fingerprint

The SHA1 fingerprint you provided (`42:C0:05:DB:3D:92:D7:39:A5:DF:25:F8:FD:72:50:4E:FE:C0:A9:1F`) is from an **existing keystore**. 

**If you create a NEW keystore, it will have a DIFFERENT SHA1 fingerprint.**

### Two Options:

#### Option 1: Use Existing Keystore (Recommended if you have it)
If you have the original keystore file that generated that SHA1:
1. Place it in `android/app/` directory
2. Create `key.properties` with the correct details
3. Build your AAB

#### Option 2: Create New Keystore
If you don't have the original keystore:
1. Create a new keystore (instructions below)
2. Note the NEW SHA1 fingerprint
3. Update Google services (Firebase, Google Sign-In, etc.) with the new SHA1
4. Build your AAB

---

## Creating a New Keystore

### Windows:
1. Open Command Prompt or PowerShell
2. Navigate to `apps/user_app/android/`
3. Run: `create_keystore.bat`
4. Follow the prompts to enter:
   - Keystore password (remember this!)
   - Key password (can be same as keystore password)
   - Your name and organization details

### Mac/Linux:
1. Open Terminal
2. Navigate to `apps/user_app/android/`
3. Make script executable: `chmod +x create_keystore.sh`
4. Run: `./create_keystore.sh`
5. Follow the prompts

### Manual Method:
```bash
cd apps/user_app/android/app
keytool -genkey -v -keystore release-key.keystore -alias release -keyalg RSA -keysize 2048 -validity 10000
```

You'll be prompted for:
- **Keystore password**: Choose a strong password (save it!)
- **Key password**: Can be same as keystore password
- **Your name**: Your full name
- **Organizational unit**: Your department/team
- **Organization**: Your company name
- **City/Locality**: Your city
- **State/Province**: Your state
- **Country code**: Two-letter code (e.g., IN, US)

---

## After Creating Keystore

### 1. Verify SHA1 Fingerprint
```bash
keytool -list -v -keystore android/app/release-key.keystore -alias release
```

Look for the SHA1 value. **Note this down** - you'll need to add it to:
- Firebase Console (Project Settings > Your Apps)
- Google Cloud Console (for Google Sign-In)
- Google Maps API (if using Maps)

### 2. Create key.properties File
Copy the template and fill in your details:
```bash
cd apps/user_app/android
cp key.properties.template key.properties
```

Edit `key.properties`:
```properties
storePassword=your_keystore_password_here
keyPassword=your_key_password_here
keyAlias=release
storeFile=../app/release-key.keystore
```

### 3. Build Signed AAB
```bash
cd apps/user_app
flutter build appbundle --release
```

---

## Finding Your Existing Keystore

If you think you might already have a keystore with that SHA1, check:

1. **Common locations:**
   - `~/.android/debug.keystore` (debug keystore)
   - `android/app/` directory
   - Previous project folders
   - Backup locations

2. **Search your computer:**
   - Windows: Search for `*.keystore` or `*.jks`
   - Mac: `find ~ -name "*.keystore" -o -name "*.jks"`
   - Linux: `find ~ -name "*.keystore" -o -name "*.jks"`

3. **Check if any keystore matches:**
   ```bash
   keytool -list -v -keystore path/to/keystore.keystore
   ```
   Look for SHA1: `42:C0:05:DB:3D:92:D7:39:A5:DF:25:F8:FD:72:50:4E:FE:C0:A9:1F`

---

## Security Reminders

- ⚠️ **NEVER** commit `key.properties` or `.keystore` files to Git
- ⚠️ **BACKUP** your keystore file in a secure location
- ⚠️ **REMEMBER** your passwords - you'll need them for all future updates
- ⚠️ If you lose the keystore, you **cannot** update your app on Play Store

---

## Need Help?

If you're unsure which option to choose:
- **New app/First time publishing**: Create new keystore (Option 2)
- **Updating existing app**: You MUST use the original keystore (Option 1)
- **Not sure**: Check with your team or look for keystore backups

