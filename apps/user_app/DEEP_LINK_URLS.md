# Deep Link URLs

All deep links now use the custom scheme `saralevents://` format. No web hosting required.

## URL Formats

### Invitation Links
```
saralevents://invite/{slug}
```

**Example:**
```
saralevents://invite/hgh-2110
```

### Referral Links
```
saralevents://refer/{code}
```

**Example:**
```
saralevents://refer/ABC123
```

### Service Links
```
saralevents://service/{serviceId}
```

**Example:**
```
saralevents://service/12345
```

## Testing with ADB

**Note:** These commands use `adb shell am start` (Android Activity Manager), NOT curl. They directly launch Android intents.

### Test Invitation Link
```bash
adb shell am start -W -a android.intent.action.VIEW -d "saralevents://invite/hgh-2110" com.saralevents.userapp
```

### Test Referral Link
```bash
adb shell am start -W -a android.intent.action.VIEW -d "saralevents://refer/ABC123" com.saralevents.userapp
```

### Test Service Link
```bash
adb shell am start -W -a android.intent.action.VIEW -d "saralevents://service/12345" com.saralevents.userapp
```

### Alternative: Using ADB with Intent URI (Android Intent URL format)
```bash
adb shell am start -W -a android.intent.action.VIEW -d "intent://invite/hgh-2110#Intent;scheme=saralevents;package=com.saralevents.userapp;end" com.saralevents.userapp
```

### What Each Part Means:
- `adb shell` - Run command on Android device
- `am start` - Android Activity Manager start command
- `-W` - Wait for launch to complete
- `-a android.intent.action.VIEW` - Action type (view a URI)
- `-d "saralevents://..."` - Data/URI to open
- `com.saralevents.userapp` - Package name (optional, helps Android find the right app)

## Usage in Chrome/Other Apps

### Android Intent URLs (Recommended for Chrome)

For better Chrome compatibility, use Android Intent URL format:
```
intent://invite/{slug}#Intent;scheme=saralevents;package=com.saralevents.userapp;end
```

**Why Android Intent URLs?**
- ✅ Chrome recognizes `intent://` scheme
- ✅ Automatically prompts to open in app
- ✅ Works when clicked from links
- ✅ Better user experience

**Example:**
```
intent://invite/hgh-2110#Intent;scheme=saralevents;package=com.saralevents.userapp;end
```

### Custom Schemes

Custom scheme links (`saralevents://`) work when:
- ✅ Clicked from links in messages/apps
- ✅ Shared via WhatsApp, Instagram, etc.
- ⚠️ May NOT work when typed directly in Chrome address bar

**Note:** The app now automatically includes both Android Intent URLs and custom scheme links when sharing, so users get the best experience.

### Testing in Chrome

1. **Open the test HTML file** (`test_deep_link.html`) in Chrome on Android
2. **Click the links** - they should prompt to open in app
3. **Or share a link** from the app - it includes both formats

### Typing Links Directly

If you want to type links directly in Chrome:
- Use Android Intent URL format (works better)
- Or create a simple redirect page (see `test_deep_link.html` for example)

## Notes

- All share functionality now uses only `saralevents://` links
- No web hosting or domain verification required
- Permissions are automatically requested when the app opens
- Links work immediately without any server setup
