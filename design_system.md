Here is all the Flutter code from the design system in one Dart listing. I checked the colors against the design system's current color list, so every value below matches it exactly, in both light and dark.

The design system's Flutter section only had the dark status colors (pending, success, danger, SLA) as comments, so I wrote them out in full here. The dark theme now builds from the same code as the light theme, and screens don't need to check which one is active.

```dart
// =============================================================================
// Seen Booking: Flutter design tokens & AppTheme
// Source: "Seen Booking" design system (tokens.json v1: light + dark)
//
// pubspec.yaml
//   dependencies:
//     flutter_localizations: { sdk: flutter }
//     intl: ^0.19.0
//   flutter:
//     fonts:
//       - family: IBM Plex Sans Arabic      # bundle TTFs (400/500/600/700), or use google_fonts
//         fonts:
//           - { asset: assets/fonts/IBMPlexSansArabic-Regular.ttf,  weight: 400 }
//           - { asset: assets/fonts/IBMPlexSansArabic-Medium.ttf,   weight: 500 }
//           - { asset: assets/fonts/IBMPlexSansArabic-SemiBold.ttf, weight: 600 }
//           - { asset: assets/fonts/IBMPlexSansArabic-Bold.ttf,     weight: 700 }
//       - family: IBM Plex Mono
//         fonts:
//           - { asset: assets/fonts/IBMPlexMono-Medium.ttf, weight: 500 }
// =============================================================================

import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// -----------------------------------------------------------------------------
// 1. COLOR PALETTE: light & dark (ThemeExtension)
//    Rule: FILL -> primary / accent.  TEXT, ICON, BORDER, RING -> primaryInk / accentInk.
// -----------------------------------------------------------------------------

enum SeenTone { pending, success, danger, sla, neutral }

@immutable
class SeenColors extends ThemeExtension<SeenColors> {
  const SeenColors({
    required this.surface,
    required this.card,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.inkDisabled,
    required this.onPrimary,
    required this.onPrimaryMuted,
    required this.primary,
    required this.primaryHover,
    required this.primarySoft,
    required this.primaryLine,
    required this.primaryInk,
    required this.slate,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.focus,
    required this.pendingBg,
    required this.pendingFg,
    required this.pendingLine,
    required this.successBg,
    required this.successFg,
    required this.successLine,
    required this.dangerBg,
    required this.dangerFg,
    required this.dangerLine,
    required this.slaBg,
    required this.slaFg,
    required this.slaSolid,
    required this.scrim,
    required this.sheetShadow,
  });

  // Surfaces & lines
  final Color surface;        // App background behind every screen
  final Color card;           // Cards, sheets, fields, top bar
  final Color surfaceSunken;  // Read-only fields, total rows, skeletons
  final Color border;         // Default 1px border / divider
  final Color borderStrong;   // Control outline (decorative; label carries meaning)
  // Text
  final Color ink;            // Primary text
  final Color inkSecondary;   // Supporting text, helper lines
  final Color inkMuted;       // Meta, timestamps, placeholders (>= 4.5:1)
  final Color inkDisabled;    // Disabled labels only
  final Color onPrimary;      // Text/icons on primary & accent fills
  final Color onPrimaryMuted; // Captions on the navy wallet card
  // Brand: navy
  final Color primary;        // Deep Executive Navy (fills)
  final Color primaryHover;   // Pressed/hover of primary
  final Color primarySoft;    // Icon tiles, info banners, unread rows
  final Color primaryLine;    // Border of primarySoft panels
  final Color primaryInk;     // Navy as text/icon (links, tags, Top-Up label)
  final Color slate;          // Secondary button text/outline, icon ink
  // Brand: burgundy (ACTIVE only, never a status)
  final Color accent;         // Selected segment, counts, traveler number (fills)
  final Color accentSoft;     // Behind active chip / nav pill
  final Color accentInk;      // Active label, selected border, current step ring
  final Color focus;          // 2px focus ring, 2px offset
  // Status: pending (sand / amber)
  final Color pendingBg, pendingFg, pendingLine;
  // Status: success (sage)
  final Color successBg, successFg, successLine;
  // Status: danger (terracotta / brick)
  final Color dangerBg, dangerFg, dangerLine;
  // Status: SLA < 24h (burnt orange)
  final Color slaBg, slaFg, slaSolid;
  // Overlays
  final Color scrim;          // Bottom-sheet barrier
  final List<BoxShadow> sheetShadow; // Bottom sheets & sticky ActionBar only

  static const light = SeenColors(
    surface: Color(0xFFF8F9FA),
    card: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF1F3F5),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    ink: Color(0xFF0F172A),
    inkSecondary: Color(0xFF475569),
    inkMuted: Color(0xFF5B6B80),
    inkDisabled: Color(0xFF94A3B8),
    onPrimary: Color(0xFFFFFFFF),
    onPrimaryMuted: Color(0xFFB4C2D9),
    primary: Color(0xFF14274A),
    primaryHover: Color(0xFF1D355F),
    primarySoft: Color(0xFFE8EDF5),
    primaryLine: Color(0xFFB9C6DB),
    primaryInk: Color(0xFF14274A),
    slate: Color(0xFF334155),
    accent: Color(0xFF8C1D2F),
    accentSoft: Color(0xFFF7EBED),
    accentInk: Color(0xFF8C1D2F),
    focus: Color(0xFF2F5596),
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
    scrim: Color(0x7A0F172A), // rgba(15,23,42,0.48)
    sheetShadow: [
      BoxShadow(color: Color(0xFFE2E8F0), offset: Offset(0, -1)),
      BoxShadow(color: Color(0x140F172A), offset: Offset(0, -8), blurRadius: 24), // 8%
    ],
  );

  static const dark = SeenColors(
    surface: Color(0xFF0B1220),
    card: Color(0xFF121B2C),
    surfaceSunken: Color(0xFF1A2436),
    border: Color(0xFF243049),
    borderStrong: Color(0xFF3A4863),
    ink: Color(0xFFE8EDF5),
    inkSecondary: Color(0xFFB3BFD1),
    inkMuted: Color(0xFF8E9BB0),
    inkDisabled: Color(0xFF5B6880),
    onPrimary: Color(0xFFFFFFFF),
    onPrimaryMuted: Color(0xFFB4C2D9),
    primary: Color(0xFF24407A),
    primaryHover: Color(0xFF2D4D8F),
    primarySoft: Color(0xFF1A2A47),
    primaryLine: Color(0xFF33476E),
    primaryInk: Color(0xFFA9C1EC),
    slate: Color(0xFFC3CDDB),
    accent: Color(0xFF9E2438),
    accentSoft: Color(0xFF3A1A22),
    accentInk: Color(0xFFF2A7B3),
    focus: Color(0xFF7AA2E8),
    pendingBg: Color(0xFF33270F),
    pendingFg: Color(0xFFE9C27A),
    pendingLine: Color(0xFF5A4520),
    successBg: Color(0xFF16301D),
    successFg: Color(0xFF8FD19E),
    successLine: Color(0xFF2B5236),
    dangerBg: Color(0xFF3A1A14),
    dangerFg: Color(0xFFF0A08E),
    dangerLine: Color(0xFF63302A),
    slaBg: Color(0xFF3B2210),
    slaFg: Color(0xFFF5A766),
    slaSolid: Color(0xFFE0762A),
    scrim: Color(0x99000000), // rgba(0,0,0,0.6)
    sheetShadow: [
      BoxShadow(color: Color(0xFF243049), offset: Offset(0, -1)),
      BoxShadow(color: Color(0x66000000), offset: Offset(0, -8), blurRadius: 24), // 40%
    ],
  );

  static SeenColors of(BuildContext context) =>
      Theme.of(context).extension<SeenColors>()!;

  /// Badge / tag / notification-icon colors for a status tone.
  ({Color bg, Color fg, Color line}) tone(SeenTone t) => switch (t) {
        SeenTone.pending => (bg: pendingBg, fg: pendingFg, line: pendingLine),
        SeenTone.success => (bg: successBg, fg: successFg, line: successLine),
        SeenTone.danger => (bg: dangerBg, fg: dangerFg, line: dangerLine),
        SeenTone.sla => (bg: slaBg, fg: slaFg, line: slaBg),
        SeenTone.neutral => (bg: surfaceSunken, fg: inkSecondary, line: border),
      };

  @override
  SeenColors copyWith() => this;

  @override
  SeenColors lerp(covariant SeenColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SeenColors(
      surface: l(surface, other.surface),
      card: l(card, other.card),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      ink: l(ink, other.ink),
      inkSecondary: l(inkSecondary, other.inkSecondary),
      inkMuted: l(inkMuted, other.inkMuted),
      inkDisabled: l(inkDisabled, other.inkDisabled),
      onPrimary: l(onPrimary, other.onPrimary),
      onPrimaryMuted: l(onPrimaryMuted, other.onPrimaryMuted),
      primary: l(primary, other.primary),
      primaryHover: l(primaryHover, other.primaryHover),
      primarySoft: l(primarySoft, other.primarySoft),
      primaryLine: l(primaryLine, other.primaryLine),
      primaryInk: l(primaryInk, other.primaryInk),
      slate: l(slate, other.slate),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      accentInk: l(accentInk, other.accentInk),
      focus: l(focus, other.focus),
      pendingBg: l(pendingBg, other.pendingBg),
      pendingFg: l(pendingFg, other.pendingFg),
      pendingLine: l(pendingLine, other.pendingLine),
      successBg: l(successBg, other.successBg),
      successFg: l(successFg, other.successFg),
      successLine: l(successLine, other.successLine),
      dangerBg: l(dangerBg, other.dangerBg),
      dangerFg: l(dangerFg, other.dangerFg),
      dangerLine: l(dangerLine, other.dangerLine),
      slaBg: l(slaBg, other.slaBg),
      slaFg: l(slaFg, other.slaFg),
      slaSolid: l(slaSolid, other.slaSolid),
      scrim: l(scrim, other.scrim),
      sheetShadow: t < .5 ? sheetShadow : other.sheetShadow,
    );
  }
}

// -----------------------------------------------------------------------------
// 2. SPACING, RADIUS, SIZES (4px base)
// -----------------------------------------------------------------------------

abstract final class SeenSpace {
  static const double s1 = 4;   // icon-label gap, badge vertical
  static const double s2 = 8;   // chip gaps, label-to-field gap
  static const double s3 = 12;  // between stacked cards / rows
  static const double s4 = 16;  // card padding, screen gutter
  static const double s5 = 20;  // field-to-field rhythm
  static const double s6 = 24;  // section spacing
  static const double s8 = 32;  // section break, sheet top padding
  static const double s10 = 40; // above sticky ActionBar content
  static const gutter = EdgeInsetsDirectional.symmetric(horizontal: s4);
}

abstract final class SeenRadius {
  static const xs = Radius.circular(4);     // badges, tags
  static const sm = Radius.circular(8);     // buttons, fields, chips, icon tiles
  static const md = Radius.circular(12);    // cards
  static const lg = Radius.circular(16);    // wallet card, sheet top corners
  static const full = Radius.circular(999); // pill chips, counts
}

abstract final class SeenSize {
  static const double hairline = 1;
  static const double touchMin = 48;
  static const double field = 52;
  static const double button = 52;
  static const double buttonSm = 40;
  static const double appBar = 56;
  static const double bottomNav = 64;
}

// -----------------------------------------------------------------------------
// 3. TYPOGRAPHY: IBM Plex Sans Arabic (+ IBM Plex Mono for references)
//    Arabic line-heights ~1.5-1.6x; never tighten, never letter-space Arabic.
// -----------------------------------------------------------------------------

abstract final class SeenFonts {
  static const sans = 'IBM Plex Sans Arabic';
  static const mono = 'IBM Plex Mono';
  static const tabular = [FontFeature.tabularFigures(), FontFeature.liningFigures()];
}

TextStyle _s(double size, double lineHeight, FontWeight w, Color c,
        {double spacing = 0, String family = SeenFonts.sans}) =>
    TextStyle(
      fontFamily: family,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: w,
      letterSpacing: spacing,
      color: c,
      leadingDistribution: TextLeadingDistribution.even,
    );

TextTheme seenTextTheme(SeenColors c) => TextTheme(
      displayMedium: _s(26, 38, FontWeight.w600, c.ink),  // display-md: screen header
      headlineSmall: _s(20, 30, FontWeight.w600, c.ink),  // headline-sm: sheet titles
      titleMedium:   _s(17, 26, FontWeight.w600, c.ink),  // title-md: card titles
      titleSmall:    _s(15, 24, FontWeight.w600, c.ink),  // title-sm: section labels
      bodyLarge:     _s(16, 26, FontWeight.w400, c.ink),  // body-lg: input text (16 = no iOS zoom)
      bodyMedium:    _s(14, 22, FontWeight.w500, c.ink),  // body-md: form labels, row text
      bodySmall:     _s(13, 20, FontWeight.w400, c.inkSecondary), // body-sm: helper text
      labelLarge:    _s(15, 22, FontWeight.w600, c.ink),  // label-lg: buttons
      labelMedium:   _s(12, 18, FontWeight.w600, c.ink),  // label-md: badges, chips, currency
      labelSmall:    _s(11, 16, FontWeight.w500, c.inkMuted, spacing: 0.11), // label-sm: meta
    );

/// Styles that have no Material slot.
@immutable
class SeenType extends ThemeExtension<SeenType> {
  const SeenType({required this.amountXl, required this.refMono});

  /// amount-xl 32/40 w600, -0.01em, tabular. Wallet available balance.
  final TextStyle amountXl;

  /// ref-mono 13/18 w500. Reference IDs, passport numbers, transaction refs.
  final TextStyle refMono;

  factory SeenType.from(SeenColors c) => SeenType(
        amountXl: _s(32, 40, FontWeight.w600, c.onPrimary, spacing: -0.32)
            .copyWith(fontFeatures: SeenFonts.tabular),
        refMono: _s(13, 18, FontWeight.w500, c.inkSecondary, family: SeenFonts.mono)
            .copyWith(fontFeatures: SeenFonts.tabular),
      );

  static SeenType of(BuildContext context) => Theme.of(context).extension<SeenType>()!;

  @override
  SeenType copyWith({TextStyle? amountXl, TextStyle? refMono}) =>
      SeenType(amountXl: amountXl ?? this.amountXl, refMono: refMono ?? this.refMono);

  @override
  SeenType lerp(covariant SeenType? o, double t) => o == null
      ? this
      : SeenType(
          amountXl: TextStyle.lerp(amountXl, o.amountXl, t)!,
          refMono: TextStyle.lerp(refMono, o.refMono, t)!,
        );
}

// -----------------------------------------------------------------------------
// 4. APP THEME
// -----------------------------------------------------------------------------

abstract final class AppTheme {
  static ThemeData get light => build(Brightness.light);
  static ThemeData get dark => build(Brightness.dark);

  static ThemeData build(Brightness brightness) {
    final c = brightness == Brightness.light ? SeenColors.light : SeenColors.dark;
    final text = seenTextTheme(c);
    final onDanger = brightness == Brightness.light ? const Color(0xFFFFFFFF) : c.surface;

    OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: const BorderRadius.all(SeenRadius.sm),
          borderSide: BorderSide(color: color, width: width),
        );
    const btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.sm));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: SeenFonts.sans,
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primarySoft,
        onPrimaryContainer: c.primaryInk,
        secondary: c.accent,
        onSecondary: c.onPrimary,
        secondaryContainer: c.accentSoft,
        onSecondaryContainer: c.accentInk,
        error: c.dangerFg,
        onError: onDanger,
        errorContainer: c.dangerBg,
        onErrorContainer: c.dangerFg,
        surface: c.card,
        onSurface: c.ink,
        onSurfaceVariant: c.inkSecondary,
        surfaceContainerLowest: c.card,
        surfaceContainerLow: c.card,
        surfaceContainer: c.card,
        surfaceContainerHigh: c.surfaceSunken,
        surfaceContainerHighest: c.surfaceSunken,
        outline: c.borderStrong,
        outlineVariant: c.border,
        scrim: c.scrim,
        shadow: const Color(0xFF000000),
        surfaceTint: const Color(0x00000000), // no M3 tinting: borders, not elevation
      ),
      textTheme: text,
      extensions: [c, SeenType.from(c)],

      // Interaction
      splashFactory: InkRipple.splashFactory,
      splashColor: c.ink.withAlpha(0x14), // 8% ink, never a colored splash
      highlightColor: c.ink.withAlpha(0x0A),
      focusColor: c.focus.withAlpha(0x1F),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconTheme: IconThemeData(color: c.slate, size: 22),

      // Top bar (56, card, bottom hairline)
      appBarTheme: AppBarTheme(
        backgroundColor: c.card,
        foregroundColor: c.ink,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: SeenSize.appBar,
        titleTextStyle: _s(16, 22, FontWeight.w600, c.ink),
        iconTheme: IconThemeData(color: c.slate, size: 22),
        shape: Border(bottom: BorderSide(color: c.border)),
      ),

      // Cards: flat, 1px border, radius-md
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: const Color(0x00000000),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SeenRadius.md),
          side: BorderSide(color: c.border),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceSunken,
          disabledForegroundColor: c.inkDisabled,
          minimumSize: const Size(0, SeenSize.button),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: SeenSpace.s6),
          textStyle: text.labelLarge,
          shape: btnShape,
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(c.primaryHover.withAlpha(0x66)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: c.card,
          foregroundColor: c.slate,
          side: BorderSide(color: c.borderStrong),
          minimumSize: const Size(0, SeenSize.button),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: SeenSpace.s6),
          textStyle: text.labelLarge,
          shape: btnShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primaryInk,
          textStyle: text.labelLarge,
          shape: btnShape,
        ),
      ),

      // Fields: label ABOVE the field (no floating label), 52px, radius-sm
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        isDense: false,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 13),
        constraints: const BoxConstraints(minHeight: SeenSize.field),
        border: field(c.borderStrong),
        enabledBorder: field(c.borderStrong),
        focusedBorder: field(c.focus, 2),
        errorBorder: field(c.dangerFg),
        focusedErrorBorder: field(c.dangerFg, 2),
        disabledBorder: field(c.border),
        hintStyle: text.bodyLarge!.copyWith(color: c.inkMuted),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall!.copyWith(color: c.dangerFg),
        prefixIconColor: c.inkMuted,
        suffixIconColor: c.inkMuted,
        suffixStyle: text.labelMedium!.copyWith(color: c.inkMuted, fontWeight: FontWeight.w500),
      ),

      dividerTheme: DividerThemeData(color: c.border, thickness: SeenSize.hairline, space: 1),

      // Bottom sheets: every confirm-with-money step
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        modalBackgroundColor: c.card,
        surfaceTintColor: const Color(0x00000000),
        modalBarrierColor: c.scrim,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: SeenRadius.lg),
        ),
      ),

      // Bottom navigation: 5 tabs, active = burgundy + accentSoft pill
      navigationBarTheme: NavigationBarThemeData(
        height: SeenSize.bottomNav,
        backgroundColor: c.card,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        indicatorColor: c.accentSoft,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 22,
              color: s.contains(WidgetState.selected) ? c.accentInk : c.inkMuted,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => text.labelSmall!.copyWith(
              color: s.contains(WidgetState.selected) ? c.accentInk : c.inkMuted,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            )),
      ),

      // Chips: segment filters & traveler chips (selected = accent fill)
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: c.accent,
        disabledColor: c.surfaceSunken,
        side: BorderSide(color: c.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: text.labelMedium!.copyWith(color: c.inkSecondary, fontWeight: FontWeight.w500),
        secondaryLabelStyle: text.labelMedium!.copyWith(color: c.onPrimary),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
        labelPadding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
      ),

      // Selection controls
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.xs)),
        side: BorderSide(color: c.borderStrong, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : const Color(0x00000000)),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.accentInk : c.borderStrong),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : c.borderStrong),
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.card),
        trackOutlineColor: const WidgetStatePropertyAll(Color(0x00000000)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceSunken,
        linearMinHeight: 4,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.surface),
        actionTextColor: brightness == Brightness.light ? c.onPrimaryMuted : c.primary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.sm)),
      ),

      badgeTheme: BadgeThemeData(
        backgroundColor: c.accent,
        textColor: c.onPrimary,
        textStyle: _s(11, 18, FontWeight.w600, c.onPrimary),
        smallSize: 8,
        largeSize: 18,
      ),

      listTileTheme: ListTileThemeData(
        tileColor: c.card,
        iconColor: c.slate,
        textColor: c.ink,
        minVerticalPadding: SeenSpace.s3,
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: SeenSpace.s4),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. MONEY & BIDI HELPERS
//    Latin digits, 2 decimals, "USD" code, always a left-to-right run.
// -----------------------------------------------------------------------------

abstract final class SeenFormat {
  static final _money = NumberFormat('#,##0.00', 'en_US');

  /// "12,480.00"
  static String money(num v) => _money.format(v);

  /// "\u2066270.00 USD\u2069": LRI/PDI isolated so it never reverses inside Arabic text.
  static String usd(num v) => '\u2066${money(v)} USD\u2069';

  /// "27/09/2026" and "14:20" (Latin digits in both locales)
  static String date(DateTime d) => DateFormat('dd/MM/yyyy', 'en_US').format(d);
  static String time(DateTime d) => DateFormat('HH:mm', 'en_US').format(d);
}

// -----------------------------------------------------------------------------
// 6. APP SETUP (Arabic RTL default, English LTR, system light/dark)
// -----------------------------------------------------------------------------
//
// import 'package:flutter_localizations/flutter_localizations.dart';
//
// MaterialApp(
//   theme: AppTheme.light,
//   darkTheme: AppTheme.dark,
//   themeMode: ThemeMode.system,                 // Light / Dark / System under Account
//   locale: const Locale('ar'),                  // toggle to Locale('en')
//   supportedLocales: const [Locale('ar'), Locale('en')],
//   localizationsDelegates: const [
//     GlobalMaterialLocalizations.delegate,
//     GlobalWidgetsLocalizations.delegate,       // sets Directionality (RTL/LTR)
//     GlobalCupertinoLocalizations.delegate,
//   ],
//   builder: (context, child) => MediaQuery(
//     data: MediaQuery.of(context).copyWith(
//       textScaler: MediaQuery.of(context).textScaler.clamp(maxScaleFactor: 1.3),
//     ),
//     child: child!,
//   ),
// );
//
// Usage inside widgets:
//   final c = SeenColors.of(context);
//   final t = SeenType.of(context);
//   Text(SeenFormat.money(12480), style: t.amountXl);
//   Container(decoration: BoxDecoration(color: c.card, boxShadow: c.sheetShadow));

// -----------------------------------------------------------------------------
// 7. WIDGET MAPPING: design component -> Flutter widget -> built on
// -----------------------------------------------------------------------------
//
// | Design component | Flutter widget            | Built on                                                        |
// |------------------|---------------------------|-----------------------------------------------------------------|
// | TopBar           | SeenTopBar                | PreferredSizeWidget + AppBar; Badge on the bell (accent count)  |
// | BottomNav        | NavigationBar             | navigationBarTheme above (5 tabs)                               |
// | ActionBar        | SeenActionBar             | Scaffold.bottomNavigationBar slot, SafeArea, c.sheetShadow      |
// | SectionHeader    | SeenSectionHeader         | Row[titleSmall, danger count pill, TextButton link]             |
// | WalletCard       | SeenWalletCard            | DecoratedBox(primary, radius-lg) + IntrinsicHeight split row    |
// | QuickAction      | SeenQuickAction           | InkWell in bordered Card; GridView.count(crossAxisCount: 4)     |
// | Button           | FilledButton / OutlinedButton / TextButton | themes above; "danger-outline" = OutlinedButton w/ dangerFg |
// | IconButton       | IconButton + Badge        | 48x48, Badge(backgroundColor: accent)                           |
// | StatusBadge      | SeenStatusBadge(status)   | DecoratedBox + Row[Icon 14, Text labelMedium]; c.tone()         |
// | SlaTag           | SeenSlaTag(deadline)      | StreamBuilder on 1-min ticker; neutral >=24h, sla <24h, danger<=0|
// | ServiceCard      | SeenServiceCard           | Card + Semantics(inMutuallyExclusiveGroup: true), accentInk border|
// | TravelerChips    | SeenTravelerChips         | horizontal ListView of ChoiceChip + "Add" ActionChip (dashed)   |
// | TextField        | SeenTextField             | label Text above TextFormField (no floating label)              |
// | ValidityHint     | SeenValidityHint(expiry)  | LinearProgressIndicator + 6-month marker; tone by months left   |
// | BreakdownTable   | SeenBreakdownTable        | Table, FixedColumnWidth for amounts; total row on surfaceSunken |
// | BalanceBanner    | SeenBalanceBanner         | DecoratedBox: primarySoft (ok) / dangerBg (insufficient)        |
// | SegmentChips     | SeenSegmentChips          | ChoiceChips; selected = accent fill, onPrimary label            |
// | RequestCard      | SeenRequestCard           | Card + InkWell -> detail route; dangerLine border if action     |
// | Stepper          | SeenStatusStepper         | custom Column (Material Stepper is too heavy)                   |
// | LedgerRow        | SeenLedgerRow             | custom Row: tone tile, title + refMono, signed tabular amount   |
// | BottomSheet      | showSeenSheet()           | showModalBottomSheet(isScrollControlled, useSafeArea) + pinned footer |
// | MethodSelector   | SeenMethodSelector        | RadioListTile-style rows; selected = accentSoft + accentInk     |
// | ApprovalCard     | SeenApprovalCard          | Card + 2x2 facts grid + two Expanded buttons (Reject | Approve) |
// | SubAgentRow      | SeenSubAgentRow           | custom Row inside a shared bordered Column                      |
// | OtpInput         | SeenOtpInput              | hidden TextField (AutofillHints.oneTimeCode) driving 6 cells    |
// | NotificationItem | SeenNotificationTile      | custom Row; unread = primarySoft fill + accentInk dot           |
// | Icon             | PhosphorIcon (Regular)    | phosphor_flutter; mirror back/forward in RTL, never ledger arrows|
//
// Rules for engineers
// - Use EdgeInsetsDirectional / AlignmentDirectional / PositionedDirectional everywhere.
// - Never hard-code white/black: onPrimary is the only "white", scrim the only overlay.
// - Amounts and refs: fontFeatures tabular; reference IDs are SelectableText.
// - Every tap target >= 48x48. Generated PDFs are always light theme.
```
