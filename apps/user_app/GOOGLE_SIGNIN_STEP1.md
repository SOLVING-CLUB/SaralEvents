# Google Sign-In Setup - Step 1: Get SHA-1 Fingerprint

## What is SHA-1 Fingerprint?
The SHA-1 fingerprint is a unique identifier for your app's signing certificate. Google needs this to verify your app when using Google Sign-In.

## Step 1: Get Your SHA-1 Fingerprint

### For Debug Build (Development/Testing)

Open your terminal/command prompt and run this command:

**Windows (PowerShell):**
```powershell
cd C:\Users\karth\.android
keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Windows (Command Prompt):**
```cmd
cd C:\Users\karth\.android
keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Mac/Linux:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### What to Look For

After running the command, you'll see output like this:

```
Certificate fingerprints:
     SHA1: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE
     SHA256: ...
```

**Copy the SHA1 value** (the long string with colons like `AA:BB:CC:DD:EE:FF:...`)

### If the debug.keystore doesn't exist

If you get an error that the file doesn't exist, Flutter will create it automatically when you first build the app. You can also create it manually:

```bash
keytool -genkey -v -keystore ~/.android/debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000
```

## Next Steps

Once you have your SHA-1 fingerprint:
1. Copy it (the full SHA1 value with colons)
2. Reply with the SHA-1 fingerprint
3. I'll guide you to Step 2: Adding it to Google Cloud Console

## Example Output

Your SHA-1 will look something like this:
```
SHA1: 12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78
```

**Important:** Keep this SHA-1 value secure. You'll need it for the next step.
