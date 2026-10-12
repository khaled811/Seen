// Seen Booking design system — typography.
// IBM Plex Sans Arabic (+ IBM Plex Mono for references).
// Arabic line-heights ~1.5-1.6x; never tighten, never letter-space Arabic.
//
// IBM Plex Sans Arabic is bundled (assets/fonts/, declared in pubspec.yaml).
// IBM Plex Mono's `.ttf` is not in the repo yet — see the commented block in
// pubspec.yaml for what to add; until then `fontFamily: SeenFonts.mono`
// silently falls back to the platform default font rather than failing the
// build.

import 'package:flutter/material.dart';

import 'seen_colors.dart';

abstract final class SeenFonts {
  static const sans = 'IBM Plex Sans Arabic';
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
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: spacing,
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );

TextTheme seenTextTheme(SeenColors c) => TextTheme(
      displayMedium: seenStyle(26, 38, FontWeight.w600, c.ink), // display-md: screen header
      headlineSmall: seenStyle(20, 30, FontWeight.w600, c.ink), // headline-sm: sheet titles
      titleMedium: seenStyle(17, 26, FontWeight.w600, c.ink), // title-md: card titles
      titleSmall: seenStyle(15, 24, FontWeight.w600, c.ink), // title-sm: section labels
      bodyLarge: seenStyle(16, 26, FontWeight.w400, c.ink), // body-lg: input text (16 = no iOS zoom)
      bodyMedium: seenStyle(14, 22, FontWeight.w500, c.ink), // body-md: form labels, row text
      bodySmall: seenStyle(13, 20, FontWeight.w400, c.inkSecondary), // body-sm: helper text
      labelLarge: seenStyle(15, 22, FontWeight.w600, c.ink), // label-lg: buttons
      labelMedium: seenStyle(12, 18, FontWeight.w600, c.ink), // label-md: badges, chips, currency
      labelSmall: seenStyle(11, 16, FontWeight.w500, c.inkMuted, spacing: 0.11), // label-sm: meta
    );

/// Styles that have no Material slot.
@immutable
class SeenType extends ThemeExtension<SeenType> {
  const SeenType({required this.amountXl, required this.refMono, required this.inputMono});

  /// amount-xl 32/40 w600, -0.01em, tabular. Wallet available balance.
  final TextStyle amountXl;

  /// ref-mono 13/18 w500. Reference IDs, passport numbers, transaction refs.
  final TextStyle refMono;

  /// Mono input text (passport number, transfer reference, OTP) — 16/24 w500.
  final TextStyle inputMono;

  factory SeenType.from(SeenColors c) => SeenType(
        amountXl: seenStyle(32, 40, FontWeight.w600, c.onPrimary, spacing: -0.32)
            .copyWith(fontFeatures: SeenFonts.tabular),
        refMono: seenStyle(13, 18, FontWeight.w500, c.inkSecondary, family: SeenFonts.mono)
            .copyWith(fontFeatures: SeenFonts.tabular),
        inputMono: seenStyle(16, 24, FontWeight.w500, c.ink, family: SeenFonts.mono, spacing: 0.64)
            .copyWith(fontFeatures: SeenFonts.tabular),
      );

  static SeenType of(BuildContext context) => Theme.of(context).extension<SeenType>()!;

  @override
  SeenType copyWith({TextStyle? amountXl, TextStyle? refMono, TextStyle? inputMono}) => SeenType(
        amountXl: amountXl ?? this.amountXl,
        refMono: refMono ?? this.refMono,
        inputMono: inputMono ?? this.inputMono,
      );

  @override
  SeenType lerp(covariant SeenType? other, double t) => other == null
      ? this
      : SeenType(
          amountXl: TextStyle.lerp(amountXl, other.amountXl, t)!,
          refMono: TextStyle.lerp(refMono, other.refMono, t)!,
          inputMono: TextStyle.lerp(inputMono, other.inputMono, t)!,
        );
}
