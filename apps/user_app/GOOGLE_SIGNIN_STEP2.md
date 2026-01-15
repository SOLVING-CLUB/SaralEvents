# Google Sign-In Setup - Step 2: Add SHA-1 to Google Cloud Console

## Your SHA-1 Fingerprint
```
34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37
```

## Step-by-Step Instructions

### 1. Open Google Cloud Console
- Go to: https://console.cloud.google.com/
- Make sure you're logged in with your Google account

### 2. Select Your Project
- If you don't have a project, create one:
  - Click the project dropdown at the top
  - Click "New Project"
  - Enter project name: "Saral Events" (or any name)
  - Click "Create"

### 3. Navigate to Credentials
- In the left sidebar, click "APIs & Services"
- Click "Credentials"

### 4. Create or Edit OAuth 2.0 Client ID

**Option A: If you already have an Android OAuth client:**
1. Find your Android OAuth 2.0 Client ID in the list
2. Click the edit (pencil) icon
3. Scroll down to "SHA-1 certificate fingerprints"
4. Click "+ ADD SHA-1 CERTIFICATE FINGERPRINT"
5. Paste: `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
6. Click "Save"

**Option B: If you need to create a new Android OAuth client:**
1. Click "Create Credentials" at the top
2. Select "OAuth client ID"
3. If prompted, configure OAuth consent screen first:
   - User Type: External (or Internal if using Google Workspace)
   - App name: "Saral Events"
   - User support email: (your email)
   - Developer contact: (your email)
   - Click "Save and Continue"
   - Scopes: Click "Save and Continue"
   - Test users: Click "Save and Continue"
   - Summary: Click "Back to Dashboard"
4. Now create OAuth client:
   - Application type: Select "Android"
   - Name: "Saral Events User App (Android)"
   - Package name: `com.saralevents.userapp`
   - SHA-1 certificate fingerprint: `34:C6:9D:08:67:8B:BE:41:42:9D:77:2E:65:C1:45:C4:F1:9D:F8:37`
   - Click "Create"

### 5. Copy Your Client ID
After creating/editing, you'll see a popup with your Client ID. It will look like:
```
314736791162-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
```

**IMPORTANT:** Copy this Client ID - you'll need it in the next step!

## What's Next?

Once you've added the SHA-1 and copied your Android Client ID:
1. Reply with "done" and your Android Client ID
2. I'll guide you to Step 3: Configure Supabase

## Troubleshooting

**Can't find Credentials page?**
- Make sure you have the correct project selected
- You need "Editor" or "Owner" role on the project

**Don't see OAuth client ID option?**
- You may need to enable Google Sign-In API first
- Go to "APIs & Services" > "Library"
- Search for "Google Sign-In API" and enable it
