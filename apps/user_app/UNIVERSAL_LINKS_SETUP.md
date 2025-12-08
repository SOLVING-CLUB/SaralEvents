# Universal Links Setup Guide

## ✅ What's Been Implemented

Universal links (https://) are now configured to work across all platforms (WhatsApp, Chrome, SMS, etc.). When users click a link, it will automatically open in your app if installed, or show a web page with an "Open in App" button.

## Configuration Files Updated

### 1. **Company Web (Hosting)**
- ✅ `/app/.well-known/assetlinks.json` - Android verification
- ✅ `/app/apple-app-site-association/route.ts` - iOS verification  
- ✅ `/app/refer/page.tsx` - Referral link landing page
- ✅ `/app/service/[id]/page.tsx` - Service link landing page
- ✅ `/app/invite/[slug]/page.tsx` - Already existed

### 2. **Android App**
- ✅ `AndroidManifest.xml` - Added universal link intent filters with `autoVerify="true"`
- ✅ Intent filters for `/invite`, `/refer`, and `/service` paths

### 3. **iOS App**
- ✅ `Info.plist` - Added associated domain `applinks:saralevents.vercel.app`

### 4. **Flutter App**
- ✅ `app_config.dart` - Centralized domain configuration
- ✅ `deep_link_helper.dart` - Generates universal links
- ✅ `app_link_handler.dart` - Handles both https:// and custom scheme links
- ✅ All share functions updated to use universal links

## Domain Configuration

Update the domain in `lib/core/config/app_config.dart`:

```dart
static const String baseUrl = 'https://saralevents.vercel.app';
```

Or set via environment variable:
```bash
flutter run --dart-define=APP_BASE_URL=https://your-domain.com
```

## Android SHA256 Fingerprint

**IMPORTANT:** You need to add your Android app's SHA256 fingerprint to verify universal links.

### Get SHA256 Fingerprint:

**Debug keystore:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Release keystore:**
```bash
keytool -list -v -keystore /path/to/your/keystore.jks -alias your-key-alias
```

### Add to Environment Variables:

In your hosting platform (Vercel/Netlify), add:
```
NEXT_PUBLIC_ANDROID_PACKAGE=com.saralevents.userapp
NEXT_PUBLIC_ANDROID_SHA256=YOUR_SHA256_FINGERPRINT_HERE
```

For multiple fingerprints (debug + release), separate with commas:
```
NEXT_PUBLIC_ANDROID_SHA256=DEBUG_SHA256,RELEASE_SHA256
```

## iOS Configuration

Add to environment variables:
```
NEXT_PUBLIC_APPLE_TEAM_ID=YOUR_TEAM_ID
NEXT_PUBLIC_IOS_BUNDLE_ID=com.saralevents.userapp
```

## How It Works

1. **User clicks link** (e.g., `https://saralevents.vercel.app/invite/abc123`) in WhatsApp/Chrome/SMS
2. **System checks** if app is installed and can handle the link
3. **If app installed:** Opens directly in app (no browser)
4. **If app not installed:** Opens web page with "Open in App" button

## Testing

### Test Universal Links:

1. **Build and install app** on device
2. **Send yourself a link** via WhatsApp:
   ```
   https://saralevents.vercel.app/invite/test-slug-123
   ```
3. **Click the link** - should open directly in app

### Verify Domain Verification:

**Android:**
```bash
# Check if domain is verified
adb shell pm get-app-links com.saralevents.userapp

# Should show: saralevents.vercel.app: verified
```

**iOS:**
- Open Settings > Developer > Associated Domains
- Check if domain appears and is verified

### Test Web Pages:

Visit these URLs in browser (should show "Open in App" page):
- `https://saralevents.vercel.app/invite/test-slug`
- `https://saralevents.vercel.app/refer?code=ABC123`
- `https://saralevents.vercel.app/service/12345`

## Link Formats

### Universal Links (Recommended - Works Everywhere)
- Invitations: `https://saralevents.vercel.app/invite/{slug}`
- Referrals: `https://saralevents.vercel.app/refer?code={code}`
- Services: `https://saralevents.vercel.app/service/{id}`

### Custom Schemes (Fallback)
- Invitations: `saralevents://invite/{slug}`
- Referrals: `saralevents://refer/{code}`
- Services: `saralevents://service/{id}`

## Troubleshooting

### Links open in browser instead of app:

1. **Check domain verification:**
   - Android: `adb shell pm get-app-links com.saralevents.userapp`
   - iOS: Check Associated Domains in Settings

2. **Verify SHA256 fingerprint** matches in `assetlinks.json`

3. **Clear app data** and reinstall app

4. **Check intent filters** in AndroidManifest.xml have `autoVerify="true"`

### Links don't work at all:

1. **Check web pages** are accessible:
   ```bash
   curl https://saralevents.vercel.app/.well-known/assetlinks.json
   curl https://saralevents.vercel.app/apple-app-site-association
   ```

2. **Verify JSON format** is correct (no redirects, correct content-type)

3. **Check app is installed** and package name matches

## Next Steps

1. ✅ Deploy company_web to your domain
2. ✅ Add SHA256 fingerprint to environment variables
3. ✅ Test universal links on real devices
4. ✅ Update domain in `app_config.dart` if different from vercel.app

## Notes

- Universal links work **without user interaction** - they open directly in app
- Custom schemes still work as fallback
- Web pages provide fallback for users without app installed
- All share functions now use universal links by default

