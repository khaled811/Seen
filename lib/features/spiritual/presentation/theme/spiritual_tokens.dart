// Spiritual & Manasik Hub — design tokens
// (docs/spiritual_feature/01-design-tokens.md). Feature-local on purpose: the
// app-wide `SeenColors` / `SeenType` stay untouched.

import 'package:flutter/material.dart';

/// Swappable colour set, exposed as a [ThemeExtension] inside the hub's Theme.
@immutable
class SpiritualTokens extends ThemeExtension<SpiritualTokens> {
  const SpiritualTokens({
    required this.bg,
    required this.bgReader,
    required this.surface,
    required this.surfaceMuted,
    required this.segmentTrack,
    required this.borderCard,
    required this.borderControl,
    required this.borderStrong,
    required this.track,
    required this.inkPrimary,
    required this.inkBody,
    required this.inkMuted,
    required this.accent,
    required this.accentTint,
    required this.accentMid,
    required this.sage,
    required this.sageTint,
    required this.sageInk,
    required this.kaabaBand,
    required this.scrim,
    required this.octagonStroke,
    required this.readerDivider,
    required this.amber,
    required this.amberBar,
  });

  final Color bg;
  final Color bgReader;
  final Color surface;
  final Color surfaceMuted;
  final Color segmentTrack;
  final Color borderCard;
  final Color borderControl;
  final Color borderStrong;
  final Color track;
  final Color inkPrimary;
  final Color inkBody;
  final Color inkMuted;
  final Color accent;
  final Color accentTint;
  final Color accentMid;
  final Color sage;
  final Color sageTint;
  final Color sageInk;
  final Color kaabaBand;
  final Color scrim;
  final Color octagonStroke;

  /// Warm hairline on the Quran reader's paper background.
  final Color readerDivider;

  /// Compass "good" accuracy: dark amber text (≥ 4.5:1 on white) and its bar.
  final Color amber;
  final Color amberBar;

  static const light = SpiritualTokens(
    bg: Color(0xFFF3FBFC),
    bgReader: Color(0xFFF6FCFD),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE8F8FA),
    segmentTrack: Color(0xFFD6F2F6),
    borderCard: Color(0xFFD3F0F4),
    borderControl: Color(0xFFB2EBF2),
    borderStrong: Color(0xFF80DEEA),
    track: Color(0xFFCFEFF3),
    inkPrimary: Color(0xFF06303A),
    inkBody: Color(0xFF2C5560),
    inkMuted: Color(0xFF4A6F7A),
    accent: Color(0xFF00838F),
    accentTint: Color(0xFFE0F7FA),
    accentMid: Color(0xFF80DEEA),
    sage: Color(0xFF3F6654),
    sageTint: Color(0xFFE9F1EC),
    sageInk: Color(0xFF2F5442),
    kaabaBand: Color(0xFFC9A96E),
    scrim: Color(0x5C1A1C1E), // 36 %
    octagonStroke: Color(0xFF8BC9D2),
    readerDivider: Color(0xFFD8F0F3),
    amber: Color(0xFF8A5A00),
    amberBar: Color(0xFFD9A441),
  );

  /// Alternate accent themes (docs/01): sage and petrol.
  SpiritualTokens withAccent(Color accent, Color tint, Color mid) =>
      copyWith(accent: accent, accentTint: tint, accentMid: mid);

  static SpiritualTokens of(BuildContext context) =>
      Theme.of(context).extension<SpiritualTokens>() ?? light;

  @override
  SpiritualTokens copyWith({Color? accent, Color? accentTint, Color? accentMid}) =>
      SpiritualTokens(
        bg: bg,
        bgReader: bgReader,
        surface: surface,
        surfaceMuted: surfaceMuted,
        segmentTrack: segmentTrack,
        borderCard: borderCard,
        borderControl: borderControl,
        borderStrong: borderStrong,
        track: track,
        inkPrimary: inkPrimary,
        inkBody: inkBody,
        inkMuted: inkMuted,
        accent: accent ?? this.accent,
        accentTint: accentTint ?? this.accentTint,
        accentMid: accentMid ?? this.accentMid,
        sage: sage,
        sageTint: sageTint,
        sageInk: sageInk,
        kaabaBand: kaabaBand,
        scrim: scrim,
        octagonStroke: octagonStroke,
        readerDivider: readerDivider,
        amber: amber,
        amberBar: amberBar,
      );

  @override
  SpiritualTokens lerp(covariant SpiritualTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SpiritualTokens(
      bg: l(bg, other.bg),
      bgReader: l(bgReader, other.bgReader),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      segmentTrack: l(segmentTrack, other.segmentTrack),
      borderCard: l(borderCard, other.borderCard),
      borderControl: l(borderControl, other.borderControl),
      borderStrong: l(borderStrong, other.borderStrong),
      track: l(track, other.track),
      inkPrimary: l(inkPrimary, other.inkPrimary),
      inkBody: l(inkBody, other.inkBody),
      inkMuted: l(inkMuted, other.inkMuted),
      accent: l(accent, other.accent),
      accentTint: l(accentTint, other.accentTint),
      accentMid: l(accentMid, other.accentMid),
      sage: l(sage, other.sage),
      sageTint: l(sageTint, other.sageTint),
      sageInk: l(sageInk, other.sageInk),
      kaabaBand: l(kaabaBand, other.kaabaBand),
      scrim: l(scrim, other.scrim),
      octagonStroke: l(octagonStroke, other.octagonStroke),
      readerDivider: l(readerDivider, other.readerDivider),
      amber: l(amber, other.amber),
      amberBar: l(amberBar, other.amberBar),
    );
  }

  /// Card recipe: 0 2 12 rgba(26,28,30,.04).
  static const cardShadow = [
    BoxShadow(color: Color(0x0A1A1C1E), offset: Offset(0, 2), blurRadius: 12),
  ];

  /// Primary floating button: 0 6 20 rgba(26,28,30,.12).
  static const floatingShadow = [
    BoxShadow(color: Color(0x1F1A1C1E), offset: Offset(0, 6), blurRadius: 20),
  ];

  /// Segmented active pill: 0 1 4 rgba(26,28,30,.08).
  static const pillShadow = [
    BoxShadow(color: Color(0x141A1C1E), offset: Offset(0, 1), blurRadius: 4),
  ];
}

/// Spacing scale and layout constants.
abstract final class SpiritualSpace {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;

  /// Screen side gutter and gap between cards.
  static const double gutter = 16;

  /// Minimum tappable size (elderly pilgrims in sunlight and crowds).
  static const double minTap = 48;
}

abstract final class SpiritualRadius {
  static const double pill = 999;
  static const double control = 14;
  static const double button = 16;
  static const double card = 22;
  static const double tile = 20;
  static const double surface = 32;
  static const double sheet = 28;
}

/// Font families: Tajawal for the UI, KFGQPC Uthmanic Script HAFS for the
/// Quran. Amiri (hadith duas) is not bundled yet and degrades to the platform
/// font (see pubspec.yaml).
abstract final class SpiritualFonts {
  static const ui = 'Tajawal';

  /// Used when a glyph is missing from [ui].
  /// Pinned to the legacy app font so the hub does not follow the app-wide
  /// `SeenFonts.sans` (Thmanyah Sans since the Figma migration).
  static const uiFallback = ['IBM Plex Sans Arabic'];
  static const quran = 'KFGQPC Uthmanic Script HAFS';

  /// Whether the bundled Quran font can draw every mark in the dataset. The
  /// KFGQPC v0.09 file cannot (five marks become placeholder circles), so
  /// `quranDisplayText` omits them when drawing. Set to true after bundling a
  /// complete font (newer KFGQPC release, Amiri Quran).
  static const quranFontHasFullMarkSet = false;
  static const dua = 'Amiri';
}

/// Type scale (docs/01 §Typography). Colour is supplied by the widget.
abstract final class SpiritualType {
  static const display = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 56, fontWeight: FontWeight.w800, height: 1.0);
  static const counterXL = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 112, fontWeight: FontWeight.w800, height: 1.0);
  static const counterL = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 96, fontWeight: FontWeight.w800, height: 1.0);
  static const compassDeg = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 46, fontWeight: FontWeight.w800, height: 1.1);
  static const h1 = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 30, fontWeight: FontWeight.w800, height: 1.3);
  static const h2 = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 24, fontWeight: FontWeight.w800, height: 1.35);
  static const title = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 21, fontWeight: FontWeight.w800, height: 1.4);
  static const section = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 20, fontWeight: FontWeight.w800, height: 1.4);
  static const bodyStrong = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 18, fontWeight: FontWeight.w700, height: 1.5);
  static const body = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 17, fontWeight: FontWeight.w500, height: 1.5);
  static const label = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 16, fontWeight: FontWeight.w700, height: 1.4);
  static const caption = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 15, fontWeight: FontWeight.w500, height: 1.5);
  static const micro = TextStyle(fontFamily: SpiritualFonts.ui, fontSize: 13, fontWeight: FontWeight.w700, height: 1.4);
  static const quran = TextStyle(fontFamily: SpiritualFonts.quran, fontFamilyFallback: ['Amiri Quran', SpiritualFonts.dua, SpiritualFonts.ui], fontSize: 30, fontWeight: FontWeight.w400, height: 2.05);
  static const dua = TextStyle(fontFamily: SpiritualFonts.dua, fontFamilyFallback: [SpiritualFonts.ui], fontSize: 25, fontWeight: FontWeight.w400, height: 1.9);
}

/// Motion tokens (docs/04). All durations go through [of] so reduce-motion
/// collapses them to zero.
abstract final class SpiritualMotion {
  static const press = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
  static const emphasis = Duration(milliseconds: 360);
  static const sheetIn = Duration(milliseconds: 280);
  static const sheetOut = Duration(milliseconds: 220);
  static const flip = Duration(milliseconds: 600);

  static const Curve pressCurve = Curves.easeOut;
  static const Curve baseCurve = Curves.easeOutCubic;
  static const Curve emphasisCurve = Curves.easeOutBack;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// [d], or [Duration.zero] when the user asked for reduced motion.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}
