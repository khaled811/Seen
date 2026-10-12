// Seen Booking design system — ThemeData assembly.
//
// Adapted from the design system's reference Flutter listing for this
// project's pinned Flutter 3.22.2 SDK: `CardThemeData` becomes `CardTheme`
// — this SDK only has the latter (`WidgetState`/`WidgetStateProperty` are
// already available here, in `package:flutter/widgets.dart`, so those are
// used as originally specified). Every value/field otherwise matches the
// spec exactly; verified line-by-line against the installed SDK source
// rather than assumed.

import 'package:flutter/material.dart';

import 'seen_colors.dart';
import 'seen_dimensions.dart';
import 'seen_typography.dart';

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
        titleTextStyle: seenStyle(16, 22, FontWeight.w600, c.ink),
        iconTheme: IconThemeData(color: c.slate, size: 22),
        shape: Border(bottom: BorderSide(color: c.border)),
      ),

      // Cards: flat, 1px border, radius-md
      cardTheme: CardTheme(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: const Color(0x00000000),
        clipBehavior: Clip.antiAlias,
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
          disabledForegroundColor: c.inkDisabled,
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
          disabledForegroundColor: c.inkDisabled,
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
        textStyle: seenStyle(11, 18, FontWeight.w600, c.onPrimary),
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
