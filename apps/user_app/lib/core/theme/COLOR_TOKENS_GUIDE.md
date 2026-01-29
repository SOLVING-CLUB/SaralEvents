# Color Tokens System - Complete Guide

## 📋 Overview

This document describes the semantic color token system implemented to normalize Light and Dark modes while preserving the existing visual identity.

---

## 🎨 Token Table

### Brand Colors (DO NOT CHANGE)

| Token | Usage | Light Value | Dark Value | Notes |
|-------|-------|-------------|------------|-------|
| `brandPrimary` | Primary buttons, CTAs, brand elements | `#FDBB42` | `#FDBB42` | Yellow - kept same in both modes |
| `brandSecondary` | Secondary actions, accents | `#9C100E` | `#9C100E` | Dark red/burgundy |
| `brandAccent` | Background accents, highlights | `#FFE8D6` | `#FFE8D6` | Soft peach |

### Background Tokens

| Token | Usage | Light Value | Dark Value |
|-------|-------|-------------|------------|
| `bgApp()` | Main app background | `#FAFAFA` | `#0A0A0A` |
| `bgSurface()` | Cards, sheets | `#FFFFFF` | `#121212` |
| `bgElevated()` | Dialogs, bottom sheets, modals | `#FFFFFF` | `#1E1E1E` |
| `bgInput()` | Input field backgrounds | `#FFFFFF` | `#1E1E1E` |

### Text Tokens

| Token | Usage | Light Value | Dark Value |
|-------|-------|-------------|------------|
| `textPrimary()` | Headings, important content | `#1A1A1A` | `#EAEAEA` |
| `textSecondary()` | Body text, descriptions | `#666666` | `#B0B0B0` |
| `textTertiary()` | Hints, captions | `#999999` | `#808080` |
| `textDisabled()` | Disabled text | `#CCCCCC` | `#555555` |

### Border & Divider Tokens

| Token | Usage | Light Value | Dark Value |
|-------|-------|-------------|------------|
| `borderDefault()` | Dividers, card outlines | `#E0E0E0` | `#333333` |
| `borderInput()` | Input borders | `#CCCCCC` | `#404040` |
| `borderInputFocused()` | Focused input borders | `#FDBB42` | `#FDBB42` |

### Icon Tokens

| Token | Usage | Light Value | Dark Value |
|-------|-------|-------------|------------|
| `iconPrimary()` | Primary icons | `#1A1A1A` | `#EAEAEA` |
| `iconSecondary()` | Secondary icons | `#666666` | `#B0B0B0` |
| `iconTertiary()` | De-emphasized icons | `#999999` | `#808080` |

### Action Tokens

| Token | Usage | Light Value | Dark Value |
|-------|-------|-------------|------------|
| `actionPrimary()` | Primary buttons | `#FDBB42` | `#FDBB42` |
| `actionSecondary()` | Secondary buttons | `#9C100E` | `#9C100E` |
| `actionPrimaryText()` | Text on primary buttons | `#000000` | `#000000` |
| `actionSecondaryText()` | Text on secondary buttons | `#FFFFFF` | `#FFFFFF` |

### State Tokens (DO NOT CHANGE VALUES)

| Token | Usage | Value (Both Modes) |
|-------|-------|---------------------|
| `stateSuccess` | Success states | `#4CAF50` |
| `stateError` | Error states | `#E53935` |
| `stateWarning` | Warning states | `#FF9800` |
| `stateInfo` | Info states | `#2196F3` |

---

## 📖 Usage Examples

### In Widgets

```dart
import 'package:saral_events_user_app/core/theme/color_tokens.dart';

// Background
Container(
  color: ColorTokens.bgSurface(context),
)

// Text
Text(
  'Hello',
  style: TextStyle(
    color: ColorTokens.textPrimary(context),
  ),
)

// Icons
Icon(
  Icons.home,
  color: ColorTokens.iconPrimary(context),
)

// Borders
Container(
  decoration: BoxDecoration(
    border: Border.all(
      color: ColorTokens.borderDefault(context),
    ),
  ),
)

// Primary Button
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: ColorTokens.actionPrimary(context),
    foregroundColor: ColorTokens.actionPrimaryText(context),
  ),
  onPressed: () {},
  child: Text('Submit'),
)
```

### In Theme Extensions (Advanced)

For theme-wide usage, tokens are already integrated into `AppTheme`. Individual widgets can use tokens directly when needed.

---

## 🔄 Migration Guide

### Before (Hardcoded Colors)

```dart
// ❌ Don't do this
Container(
  color: Colors.white,
  child: Text(
    'Hello',
    style: TextStyle(color: Colors.black87),
  ),
)
```

### After (Using Tokens)

```dart
// ✅ Do this
Container(
  color: ColorTokens.bgSurface(context),
  child: Text(
    'Hello',
    style: TextStyle(color: ColorTokens.textPrimary(context)),
  ),
)
```

### Common Replacements

| Old Code | New Code |
|----------|----------|
| `Colors.white` | `ColorTokens.bgSurface(context)` |
| `Colors.black87` | `ColorTokens.textPrimary(context)` |
| `Colors.grey.shade600` | `ColorTokens.textSecondary(context)` |
| `Colors.grey.shade300` | `ColorTokens.iconSecondary(context)` |
| `Colors.grey.shade200` | `ColorTokens.borderDefault(context)` |
| `Theme.of(context).colorScheme.primary` | `ColorTokens.actionPrimary(context)` |

---

## ✅ What Was Changed

### Theme Files Updated
- ✅ `app_theme.dart` - Updated to use tokens
- ✅ `color_tokens.dart` - New token system created

### Components Using Tokens
- ✅ AppBar (background, foreground)
- ✅ InputDecoration (fill, borders, labels, hints)
- ✅ BottomNavigationBar (selected/unselected colors)
- ✅ ChipTheme (background, label, border)
- ✅ CardTheme (background)
- ✅ ElevatedButtonTheme (background, foreground)
- ✅ TextTheme (all text styles)
- ✅ DividerTheme (color)
- ✅ ListTileTheme (tile, text, icon colors)

---

## ⚠️ What Was NOT Changed

### Brand Colors
- ✅ Primary yellow (`#FDBB42`) - unchanged
- ✅ Secondary red (`#9C100E`) - unchanged
- ✅ Accent peach (`#FFE8D6`) - unchanged

### State Colors
- ✅ Success green - unchanged
- ✅ Error red - unchanged
- ✅ Warning orange - unchanged
- ✅ Info blue - unchanged

### Meaning-Conveying Colors
- ✅ Any color that conveys meaning (not just style) remains unchanged

---

## 🎯 Benefits

1. **Consistency**: Same token names in Light and Dark modes
2. **Maintainability**: Change token value once, updates everywhere
3. **Dark Mode**: Proper contrast ratios, no pure black/white
4. **Future-Proof**: New UI automatically supports dark mode
5. **Zero Regression**: Light mode looks exactly the same

---

## 📝 Next Steps

1. Gradually migrate hardcoded colors to tokens in individual widgets
2. Test dark mode across all screens
3. Verify contrast ratios meet accessibility standards
4. Document any custom colors that intentionally differ

---

## 🔍 Finding Hardcoded Colors

To find hardcoded colors that should be migrated:

```bash
# Search for common patterns
grep -r "Color(0x" lib/
grep -r "Colors\." lib/
grep -r "Colors\.white" lib/
grep -r "Colors\.black" lib/
```

Then replace with appropriate tokens based on context.
