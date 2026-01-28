# How to Create FCM Base64 Key

## 📋 Step-by-Step Instructions

### Step 1: Get Your Firebase Service Account JSON

1. **Go to:** [Firebase Console](https://console.firebase.google.com)
2. **Select your project:** `saralevents-6fe20`
3. **Go to:** Project Settings (gear icon) > **Service Accounts** tab
4. **Click:** "Generate new private key" (or download existing one)
5. **Save the file:** It will be named like `saralevents-6fe20-firebase-adminsdk-xxxxx-xxxxx.json`

### Step 2: Convert JSON to Base64 (Windows PowerShell)

**Option A: Using PowerShell (Recommended)**

```powershell
# Navigate to where your JSON file is saved
cd "C:\Users\karth\Downloads"

# Read the JSON file and convert to Base64
$jsonContent = Get-Content "saralevents-6fe20-firebase-adminsdk-fbsvc-cf1f5a62d6.json" -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonContent)
$base64 = [Convert]::ToBase64String($bytes)

# Display the base64 (first 100 characters)
Write-Host "Base64 (first 100 chars): $($base64.Substring(0, [Math]::Min(100, $base64.Length)))..."
Write-Host "Full length: $($base64.Length) characters"
```

**Option B: One-liner to Set Secret Directly**

```powershell
# Replace the path with your actual JSON file path
$jsonContent = Get-Content "C:\Users\karth\Downloads\saralevents-6fe20-firebase-adminsdk-fbsvc-cf1f5a62d6.json" -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonContent)
$base64 = [Convert]::ToBase64String($bytes)
npx supabase secrets set FCM_SERVICE_ACCOUNT_BASE64="$base64"
```

### Step 3: Verify the Secret is Set

```powershell
npx supabase secrets list
```

You should see `FCM_SERVICE_ACCOUNT_BASE64` in the list.

## 🔍 Verify Your JSON File

Your JSON file should look like this:

```json
{
  "type": "service_account",
  "project_id": "saralevents-6fe20",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@saralevents-6fe20.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "...",
  "universe_domain": "googleapis.com"
}
```

## ⚠️ Important Notes

1. **Private Key Format:** The `private_key` field should have `\n` (newline characters) in the JSON file. These will be preserved when converting to base64.

2. **File Path:** Make sure the path to your JSON file is correct in the PowerShell command.

3. **No Spaces:** When setting the secret, make sure there are no extra spaces around the `=` sign.

## 🧪 Test After Setting

After setting the secret, test the notification:

```sql
SELECT send_push_notification(
  'YOUR_USER_ID'::UUID,
  'Test After FCM Update',
  'Testing after updating FCM secret',
  '{"type":"test"}'::JSONB,
  NULL,
  ARRAY['user_app']::TEXT[]
);
```

Then check Dashboard logs to verify it's working.

## 🔧 Troubleshooting

### Issue: "FCM service account not configured"
**Solution:** The secret isn't set. Run the set command again.

### Issue: "Failed to get access token"
**Solution:** 
1. Verify your JSON file is valid
2. Check that the service account has "Firebase Cloud Messaging API" enabled
3. Re-set the secret

### Issue: "Invalid JSON"
**Solution:** Make sure you're reading the entire file with `-Raw` flag in PowerShell.
