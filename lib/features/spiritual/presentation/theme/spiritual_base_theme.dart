// Frozen pre-Figma base theme for the Spiritual hub.
//
// The hub derives its ThemeData from a base theme (`SpiritualTheme.data`).
// That base used to be the app theme, so the Figma migration of the app-wide
// tokens (violet palette, Thmanyah Sans, new text scale) would have leaked
// into the hub's Material widgets (sheets, dialogs, buttons, fields). This
// file pins the base to the legacy token values instead, so the hub does not
// drift. Dark values are the app's own `SeenColors.dark`, which the migration
// did not change.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';

abstract final class SpiritualBaseTheme {
  static const _font = 'IBM Plex Sans Arabic';

  static final ThemeData _light = AppTheme.build(
    Brightness.light,
    colors: _legacyLight,
    textTheme: _legacyTextTheme(_legacyLight),
    fontFamily: _font,
    fontFamilyFallback: null,
  );

  static final ThemeData _dark = AppTheme.build(
    Brightness.dark,
    colors: SeenColors.dark,
    textTheme: _legacyTextTheme(SeenColors.dark),
    fontFamily: _font,
    fontFamilyFallback: null,
  );

  static ThemeData of(Brightness brightness) => brightness == Brightness.light ? _light : _dark;

  static TextStyle _s(double size, double line, FontWeight w, Color color, {double spacing = 0}) =>
      seenStyle(size, line, w, color, spacing: spacing, family: _font);

  static TextTheme _legacyTextTheme(SeenColors c) => TextTheme(
        displayMedium: _s(26, 38, FontWeight.w600, c.ink),
        headlineSmall: _s(20, 30, FontWeight.w600, c.ink),
        titleMedium: _s(17, 26, FontWeight.w600, c.ink),
        titleSmall: _s(15, 24, FontWeight.w600, c.ink),
        bodyLarge: _s(16, 26, FontWeight.w400, c.ink),
        bodyMedium: _s(14, 22, FontWeight.w500, c.ink),
        bodySmall: _s(13, 20, FontWeight.w400, c.inkSecondary),
        labelLarge: _s(15, 22, FontWeight.w600, c.ink),
        labelMedium: _s(12, 18, FontWeight.w600, c.ink),
        labelSmall: _s(11, 16, FontWeight.w500, c.inkMuted, spacing: 0.11),
      );

  /// The app's light palette before the Figma migration (teal).
  static const _legacyLight = SeenColors(
    surface: Color(0xFFF3FBFC),
    card: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFE0F7FA),
    border: Color(0xFFB2EBF2),
    borderStrong: Color(0xFF80DEEA),
    ink: Color(0xFF06303A),
    inkSecondary: Color(0xFF2C5560),
    inkMuted: Color(0xFF4A6F7A),
    inkDisabled: Color(0xFF8DB3BB),
    onPrimary: Color(0xFFFFFFFF),
    onPrimaryMuted: Color(0xFFD3F4F8),
    primary: Color(0xFF00838F),
    primaryHover: Color(0xFF006C77),
    primarySoft: Color(0xFFE0F7FA),
    primaryLine: Color(0xFF80DEEA),
    primaryInk: Color(0xFF00606B),
    slate: Color(0xFF2C5560),
    accent: Color(0xFF00838F),
    accentSoft: Color(0xFFB2EBF2),
    accentInk: Color(0xFF00606B),
    focus: Color(0xFF00ACC1),
    pendingBg: Color(0xFFFBF4E6),
    pendingFg: Color(0xFF7D5410),
    pendingLine: Color(0xFFECD9B3),
    successBg: Color(0xFFEDF4EE),
    successFg: Color(0xFF2F6A3C),
    successLine: Color(0xFFCBE0CF),
    dangerBg: Color(0xFFF9ECE8),
    dangerFg: Color(0xFF9A3A26),
    dangerLine: Color(0xFFECCABF),
    slaBg: Color(0xFFFDEFE3),
    slaFg: Color(0xFFA8480A),
    slaSolid: Color(0xFFC2560F),
    scrim: Color(0x7A0F172A),
    sheetShadow: [
      BoxShadow(color: Color(0xFFE2E8F0), offset: Offset(0, -1)),
      BoxShadow(color: Color(0x140F172A), offset: Offset(0, -8), blurRadius: 24),
    ],
  );
}
