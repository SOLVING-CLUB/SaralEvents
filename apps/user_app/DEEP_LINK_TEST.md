# Deep Link Testing Guide

## Test Commands

### Android (via ADB)
```bash
# Test invitation link (custom scheme)
adb shell am start -W -a android.intent.action.VIEW -d "saralevents://invite/test-slug-123" com.mycompany.saralevents

# Test referral link (custom scheme)
adb shell am start -W -a android.intent.action.VIEW -d "saralevents://refer/ABC123" com.mycompany.saralevents

# Test universal link (https)
adb shell am start -W -a android.intent.action.VIEW -d "https://saralevents.vercel.app/invite/test-slug-123" com.mycompany.saralevents

# Test referral universal link
adb shell am start -W -a android.intent.action.VIEW -d "https://saralevents.vercel.app/refer?code=ABC123" com.mycompany.saralevents
```

### iOS (via Simulator Terminal)
```bash
# Test invitation link
xcrun simctl openurl booted "saralevents://invite/test-slug-123"

# Test referral link
xcrun simctl openurl booted "saralevents://refer/ABC123"

# Test universal link
xcrun simctl openurl booted "https://saralevents.vercel.app/invite/test-slug-123"
```

## Supported Link Formats

1. **Invitation Links:**
   - `saralevents://invite/:slug`
   - `https://saralevents.vercel.app/invite/:slug`

2. **Referral Links:**
   - `saralevents://refer/:code`
   - `saralevents://refer?code=:code`
   - `https://saralevents.vercel.app/refer?code=:code`

3. **Auth Confirmation:**
   - `saralevents://auth/confirm`

## Debugging

Check console logs for:
- `🔗 Initial link:` - When app opens from a link
- `🔗 Incoming link:` - When app receives link while running
- `🔗 Processing:` - Link being handled
- `⚠️ Unhandled link:` - Link format not recognized

## Notes

- Universal links require domain verification (assetlinks.json for Android, apple-app-site-association for iOS)
- Custom scheme links work immediately without verification
- App must be installed for links to work

