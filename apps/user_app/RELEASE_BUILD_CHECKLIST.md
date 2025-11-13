# Release Build Deep Linking Checklist

## ✅ What's Already Configured

### Android
- ✅ ProGuard rules added to prevent obfuscation of deep linking classes
- ✅ MainActivity kept from obfuscation
- ✅ Intent filters configured in AndroidManifest.xml
- ✅ Custom scheme `saralevents://` registered

### iOS
- ✅ URL scheme `saralevents` registered in Info.plist
- ✅ CFBundleURLTypes configured correctly

## Testing Release Builds

### Android Release Build
```bash
# Build release APK
flutter build apk --release

# Or build App Bundle
flutter build appbundle --release

# Test deep link
adb install build/app/outputs/flutter-apk/app-release.apk
adb shell am start -W -a android.intent.action.VIEW -d "saralevents://invite/test-slug" com.mycompany.saralevents
```

### iOS Release Build
```bash
# Build release
flutter build ios --release

# Test deep link (on device)
xcrun simctl openurl booted "saralevents://invite/test-slug"
```

## Important Notes

1. **ProGuard/R8**: The ProGuard rules ensure that:
   - MainActivity is not obfuscated
   - Flutter embedding classes are preserved
   - Intent handling methods are kept
   - app_links package classes are preserved

2. **Custom Schemes**: Since we're using custom schemes (`saralevents://`):
   - ✅ Works immediately without domain verification
   - ✅ Works in release builds
   - ✅ No server configuration needed
   - ⚠️ Users may see a prompt to open in app (this is normal)

3. **Intent Filters**: The AndroidManifest.xml intent filters are:
   - ✅ Included in release builds automatically
   - ✅ Not affected by ProGuard
   - ✅ Work the same in debug and release

## Verification Steps

1. Build release APK/AAB
2. Install on a device (not emulator for best testing)
3. Test deep links using adb commands
4. Test sharing links from within the app
5. Test opening links from Chrome/browser
6. Test opening links from other apps (WhatsApp, etc.)

## Troubleshooting

If deep links don't work in release build:

1. **Check ProGuard rules**: Ensure `proguard-rules.pro` is included
2. **Check AndroidManifest**: Verify intent filters are present
3. **Check package name**: Ensure `com.mycompany.saralevents` matches everywhere
4. **Test with adb**: Use `adb logcat | grep -i "intent\|deep\|link"` to debug
5. **Check app installation**: Uninstall debug version before installing release

## Expected Behavior

- ✅ Links work in release builds
- ✅ Links work when app is closed (cold start)
- ✅ Links work when app is running (warm start)
- ✅ Links work from Chrome/browser
- ✅ Links work from other apps
- ⚠️ Android may show "Open with" dialog (normal for custom schemes)
- ✅ iOS opens directly in app

