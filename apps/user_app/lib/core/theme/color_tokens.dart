import 'package:flutter/material.dart';

/// Semantic color tokens for consistent theming
/// Light and Dark modes use the same token names, only values differ
class ColorTokens {
  // ============================================
  // BRAND COLORS (DO NOT CHANGE)
  // ============================================
  /// Primary brand color - Yellow (#FDBB42)
  /// Used for: Primary buttons, CTAs, brand elements
  static const Color brandPrimary = Color(0xFFFDBB42);
  
  /// Secondary brand color - Dark Red/Burgundy (#9C100E)
  /// Used for: Secondary actions, accents
  static const Color brandSecondary = Color(0xFF9C100E);
  
  /// Accent color - Soft Peach (#FFE8D6)
  /// Used for: Background accents, highlights
  static const Color brandAccent = Color(0xFFFFE8D6);
  
  // ============================================
  // SEMANTIC TOKENS - BACKGROUNDS
  // ============================================
  
  /// Main app background
  /// Light: #FAFAFA | Dark: #0A0A0A
  static Color bgApp(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0A0A0A)  // Dark: Very dark background
        : const Color(0xFFFAFAFA);  // Light: Light gray background
  }
  
  /// Card/Surface background
  /// Light: #FFFFFF | Dark: #121212
  static Color bgSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF121212)  // Dark: Material dark surface
        : Colors.white;              // Light: White
  }
  
  /// Elevated surface (dialogs, bottom sheets, modals)
  /// Light: #FFFFFF | Dark: #1E1E1E
  static Color bgElevated(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)  // Dark: Slightly lighter dark surface
        : Colors.white;             // Light: White
  }
  
  /// Input field background
  /// Light: #FFFFFF | Dark: #1E1E1E
  static Color bgInput(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)  // Dark: Same as elevated
        : Colors.white;             // Light: White
  }
  
  // ============================================
  // SEMANTIC TOKENS - TEXT
  // ============================================
  
  /// Primary text (headings, important content)
  /// Light: #1A1A1A | Dark: #EAEAEA
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFEAEAEA)  // Dark: Soft white
        : const Color(0xFF1A1A1A);  // Light: Near black
  }
  
  /// Secondary text (body, descriptions)
  /// Light: #666666 | Dark: #B0B0B0
  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB0B0B0)  // Dark: Medium gray
        : const Color(0xFF666666);  // Light: Medium gray
  }
  
  /// Tertiary text (hints, captions)
  /// Light: #999999 | Dark: #808080
  static Color textTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF808080)  // Dark: Darker gray
        : const Color(0xFF999999);  // Light: Lighter gray
  }
  
  /// Disabled text
  /// Light: #CCCCCC | Dark: #555555
  static Color textDisabled(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF555555)  // Dark: Very dark gray
        : const Color(0xFFCCCCCC);  // Light: Light gray
  }
  
  // ============================================
  // SEMANTIC TOKENS - BORDERS & DIVIDERS
  // ============================================
  
  /// Default border/divider color
  /// Light: #E0E0E0 | Dark: #333333
  static Color borderDefault(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF333333)  // Dark: Dark gray border
        : const Color(0xFFE0E0E0);  // Light: Light gray border
  }
  
  /// Input border color
  /// Light: #CCCCCC | Dark: #404040
  static Color borderInput(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF404040)  // Dark: Medium dark gray
        : const Color(0xFFCCCCCC);  // Light: Light gray
  }
  
  /// Focused input border color (uses primary brand color)
  static Color borderInputFocused(BuildContext context) {
    return brandPrimary;
  }
  
  // ============================================
  // SEMANTIC TOKENS - ICONS
  // ============================================
  
  /// Primary icon color
  /// Light: #1A1A1A | Dark: #EAEAEA
  static Color iconPrimary(BuildContext context) {
    return textPrimary(context);
  }
  
  /// Secondary icon color
  /// Light: #666666 | Dark: #B0B0B0
  static Color iconSecondary(BuildContext context) {
    return textSecondary(context);
  }
  
  /// Tertiary icon color (de-emphasized)
  /// Light: #999999 | Dark: #808080
  static Color iconTertiary(BuildContext context) {
    return textTertiary(context);
  }
  
  // ============================================
  // SEMANTIC TOKENS - ACTIONS
  // ============================================
  
  /// Primary action color (uses brand primary)
  static Color actionPrimary(BuildContext context) {
    return brandPrimary;
  }
  
  /// Secondary action color (uses brand secondary)
  static Color actionSecondary(BuildContext context) {
    return brandSecondary;
  }
  
  /// Primary action text color (on primary background)
  /// Light: #000000 | Dark: #000000
  static Color actionPrimaryText(BuildContext context) {
    return Colors.black87; // Black text on yellow works for both modes
  }
  
  /// Secondary action text color (on secondary background)
  /// Light: #FFFFFF | Dark: #FFFFFF
  static Color actionSecondaryText(BuildContext context) {
    return Colors.white; // White text on dark red
  }
  
  // ============================================
  // SEMANTIC TOKENS - STATES (DO NOT CHANGE COLORS)
  // ============================================
  
  /// Success color (green)
  static const Color stateSuccess = Color(0xFF4CAF50);
  
  /// Error color (red)
  static const Color stateError = Color(0xFFE53935);
  
  /// Warning color (orange/amber)
  static const Color stateWarning = Color(0xFFFF9800);
  
  /// Info color (blue)
  static const Color stateInfo = Color(0xFF2196F3);
  
  // ============================================
  // HELPER METHODS
  // ============================================
  
  /// Get opacity variant of a color
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
  
  /// Check if current theme is dark
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}
