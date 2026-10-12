// Seen Booking design system — typography.
// Official Figma typeface: Thmanyah Sans (bundled .otf, declared in
// pubspec.yaml at 300/400/500/700/900). The legacy IBM Plex Sans Arabic stays
// bundled and acts as `fontFamilyFallback`. IBM Plex Mono is not bundled, so
// `SeenFonts.mono` silently falls back to the platform default font.
// Arabic line-heights ~1.5-1.6x; never tighten, never letter-space Arabic.
//
// Figma text styles (size/line-height):
//   Amount 32/40 w500 · Display 26/36 w700 · H1 22/32 w700 · H2 18/28 w500 ·
//   Title 16/24 w500 · Body strong 14/22 w500 · Body 14/22 w400 ·
//   Label 13/20 w500 · Caption 11/16 w400
// (The Figma type-scale page labels H1 "SemiBold"; the bound variable and every
// screen use Bold, so Bold is used here. Thmanyah has no 600 weight.)

import 'package:flutter/material.dart';

import 'seen_colors.dart';

abstract final class SeenFonts {
  static const sans = 'Thmanyah Sans';
  static const sansFallback = ['IBM Plex Sans Arabic'];
  static const mono = 'IBM Plex Mono';
  static const tabular = [FontFeature.tabularFigures(), FontFeature.liningFigures()];
}

/// Shared style builder — also used directly by `AppTheme` for the two
/// slots (app bar title, badge text) that have no `TextTheme` counterpart.
TextStyle seenStyle(
  double size,
  double lineHeight,
  FontWeight weight,
  Color color, {
  double spacing = 0,
  String family = SeenFonts.sans,
}) =>
    TextStyle(
      fontFamily: family,
      fontFamilyFallback: family == SeenFonts.sans ? SeenFonts.sansFallback : null,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: spacing,
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );

/// Material slots mapped onto the Figma scale.
TextTheme seenTextTheme(SeenColors c) => TextTheme(
      displayMedium: seenStyle(26, 36, FontWeight.w700, c.ink), // Display: welcome headline
      headlineSmall: seenStyle(22, 32, FontWeight.w700, c.ink), // H1 · Screen: screen headers
      titleLarge: seenStyle(18, 28, FontWeight.w500, c.ink), // H2 · Section
      titleMedium: seenStyle(16, 24, FontWeight.w500, c.ink), // Title: card / sheet titles
      titleSmall: seenStyle(14, 22, FontWeight.w500, c.ink), // Body strong: section labels
      bodyLarge: seenStyle(14, 22, FontWeight.w400, c.ink), // Body: input text (Figma fields are 14)
      bodyMedium: seenStyle(14, 22, FontWeight.w500, c.ink), // Body strong: row text
      bodySmall: seenStyle(11, 16, FontWeight.w400, c.inkMuted), // Caption: helper text
      labelLarge: seenStyle(15, 22, FontWeight.w500, c.ink), // Button M label
      labelMedium: seenStyle(13, 20, FontWeight.w500, c.ink), // Label: form labels, chips (M)
      labelSmall: seenStyle(11, 16, FontWeight.w400, c.inkMuted), // Caption: meta
    );

/// Styles that have no Material slot, plus the explicit Figma names for the
/// styles the slots approximate. Figma styles default to `ink`; widgets
/// `copyWith(color: ...)` for muted / link / on-brand variants.
@immutable
class SeenType extends ThemeExtension<SeenType> {
  const SeenType({
    required this.amountXl,
    required this.refMono,
    required this.inputMono,
    required this.display,
    required this.h1,
    required this.h2,
    required this.title,
    required this.bodyStrong,
    required this.body,
    required this.label,
    required this.caption,
    required this.buttonL,
    required this.buttonM,
    required this.buttonS,
    required this.buttonXs,
    required this.chipS,
    required this.chipM,
  });

  /// Figma "Amount" 32/40 w500, tabular. Wallet balance (white on the card).
  final TextStyle amountXl;

  /// ref-mono 13/18 w500. Legacy: not used by the Figma designs, which set
  /// reference IDs in [label] with the link color.
  final TextStyle refMono;

  /// Mono input text 16/24 w500. Legacy, see [refMono].
  final TextStyle inputMono;

  /// Figma styles (size/line-height, weight).
  final TextStyle display; // 26/36 w700
  final TextStyle h1; // 22/32 w700 — "H1 · Screen"
  final TextStyle h2; // 18/28 w500 — "H2 · Section"
  final TextStyle title; // 16/24 w500
  final TextStyle bodyStrong; // 14/22 w500
  final TextStyle body; // 14/22 w400
  final TextStyle label; // 13/20 w500
  final TextStyle caption; // 11/16 w400

  /// Button labels, all w500 (Figma: L 18, M 15, S 13, XS 12; line-height 22).
  final TextStyle buttonL;
  final TextStyle buttonM;
  final TextStyle buttonS;
  final TextStyle buttonXs;

  /// Status chip labels, w500 (Figma: S 12/20, M 13/20).
  final TextStyle chipS;
  final TextStyle chipM;

  factory SeenType.from(SeenColors c) => SeenType(
        amountXl: seenStyle(32, 40, FontWeight.w500, c.onPrimary).copyWith(fontFeatures: SeenFonts.tabular),
        refMono: seenStyle(13, 18, FontWeight.w500, c.inkSecondary, family: SeenFonts.mono)
            .copyWith(fontFeatures: SeenFonts.tabular),
        inputMono: seenStyle(16, 24, FontWeight.w500, c.ink, family: SeenFonts.mono, spacing: 0.64)
            .copyWith(fontFeatures: SeenFonts.tabular),
        display: seenStyle(26, 36, FontWeight.w700, c.ink),
        h1: seenStyle(22, 32, FontWeight.w700, c.ink),
        h2: seenStyle(18, 28, FontWeight.w500, c.ink),
        title: seenStyle(16, 24, FontWeight.w500, c.ink),
        bodyStrong: seenStyle(14, 22, FontWeight.w500, c.ink),
        body: seenStyle(14, 22, FontWeight.w400, c.ink),
        label: seenStyle(13, 20, FontWeight.w500, c.ink),
        caption: seenStyle(11, 16, FontWeight.w400, c.ink),
        buttonL: seenStyle(18, 22, FontWeight.w500, c.onPrimary),
        buttonM: seenStyle(15, 22, FontWeight.w500, c.onPrimary),
        buttonS: seenStyle(13, 22, FontWeight.w500, c.onPrimary),
        buttonXs: seenStyle(12, 22, FontWeight.w500, c.onPrimary),
        chipS: seenStyle(12, 20, FontWeight.w500, c.ink),
        chipM: seenStyle(13, 20, FontWeight.w500, c.ink),
      );

  static SeenType of(BuildContext context) => Theme.of(context).extension<SeenType>()!;

  @override
  SeenType copyWith({
    TextStyle? amountXl,
    TextStyle? refMono,
    TextStyle? inputMono,
    TextStyle? display,
    TextStyle? h1,
    TextStyle? h2,
    TextStyle? title,
    TextStyle? bodyStrong,
    TextStyle? body,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? buttonL,
    TextStyle? buttonM,
    TextStyle? buttonS,
    TextStyle? buttonXs,
    TextStyle? chipS,
    TextStyle? chipM,
  }) =>
      SeenType(
        amountXl: amountXl ?? this.amountXl,
        refMono: refMono ?? this.refMono,
        inputMono: inputMono ?? this.inputMono,
        display: display ?? this.display,
        h1: h1 ?? this.h1,
        h2: h2 ?? this.h2,
        title: title ?? this.title,
        bodyStrong: bodyStrong ?? this.bodyStrong,
        body: body ?? this.body,
        label: label ?? this.label,
        caption: caption ?? this.caption,
        buttonL: buttonL ?? this.buttonL,
        buttonM: buttonM ?? this.buttonM,
        buttonS: buttonS ?? this.buttonS,
        buttonXs: buttonXs ?? this.buttonXs,
        chipS: chipS ?? this.chipS,
        chipM: chipM ?? this.chipM,
      );

  @override
  SeenType lerp(covariant SeenType? other, double t) {
    if (other == null) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return SeenType(
      amountXl: l(amountXl, other.amountXl),
      refMono: l(refMono, other.refMono),
      inputMono: l(inputMono, other.inputMono),
      display: l(display, other.display),
      h1: l(h1, other.h1),
      h2: l(h2, other.h2),
      title: l(title, other.title),
      bodyStrong: l(bodyStrong, other.bodyStrong),
      body: l(body, other.body),
      label: l(label, other.label),
      caption: l(caption, other.caption),
      buttonL: l(buttonL, other.buttonL),
      buttonM: l(buttonM, other.buttonM),
      buttonS: l(buttonS, other.buttonS),
      buttonXs: l(buttonXs, other.buttonXs),
      chipS: l(chipS, other.chipS),
      chipM: l(chipM, other.chipM),
    );
  }
}
