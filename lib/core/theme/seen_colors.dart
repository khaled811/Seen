// Seen Booking design system — color tokens.
// Light: official Figma file "Seen Booking – Mobile App (light)" (Seen Violet,
// Foundations + Request statuses pages). Dark: legacy values, kept intact —
// Figma has no dark theme yet.
//
// Rule: FILL -> primary / accent.  TEXT, ICON, BORDER, RING -> primaryInk / accentInk.
// Figma has a single brand hue, so the legacy burgundy `accent*` tokens are
// aliases of the violet `primary*` tokens in light.
//
// Figma-only light tokens that have no dark counterpart (violet ramp,
// gradients, the 12 request statuses) live in [SeenBrand] and
// [SeenRequestStatus] at the bottom of this file; semantic [SeenColors]
// fields stay the theme-aware API for widgets.

import 'package:flutter/material.dart';

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
  final Color surface; // App background behind every screen
  final Color card; // Cards, sheets, fields, top bar
  final Color surfaceSunken; // Read-only fields, total rows, skeletons
  final Color border; // Default 1px border / divider
  final Color borderStrong; // Control outline (decorative; label carries meaning)
  // Text
  final Color ink; // Primary text
  final Color inkSecondary; // Supporting text, helper lines
  final Color inkMuted; // Meta, timestamps, placeholders (>= 4.5:1)
  final Color inkDisabled; // Disabled labels only
  final Color onPrimary; // Text/icons on primary & accent fills
  final Color onPrimaryMuted; // Captions on the navy wallet card
  // Brand: navy
  final Color primary; // Deep Executive Navy (fills)
  final Color primaryHover; // Pressed/hover of primary
  final Color primarySoft; // Icon tiles, info banners, unread rows
  final Color primaryLine; // Border of primarySoft panels
  final Color primaryInk; // Navy as text/icon (links, tags, Top-Up label)
  final Color slate; // Secondary button text/outline, icon ink
  // Brand: burgundy (ACTIVE only, never a status)
  final Color accent; // Selected segment, counts, traveler number (fills)
  final Color accentSoft; // Behind active chip / nav pill
  final Color accentInk; // Active label, selected border, current step ring
  final Color focus; // 2px focus ring, 2px offset
  // Status: pending (sand / amber)
  final Color pendingBg, pendingFg, pendingLine;
  // Status: success (sage)
  final Color successBg, successFg, successLine;
  // Status: danger (terracotta / brick)
  final Color dangerBg, dangerFg, dangerLine;
  // Status: SLA < 24h (burnt orange)
  final Color slaBg, slaFg, slaSolid;
  // Overlays
  final Color scrim; // Bottom-sheet barrier
  final List<BoxShadow> sheetShadow; // Bottom sheets & sticky ActionBar only

  // Figma light tokens. Legacy tone fields map onto the Figma statuses:
  // pending = action required, success = completed, danger = rejected,
  // sla = deadline < 24h. Figma chips have no border, so `*Line` = `*Bg`.
  static const light = SeenColors(
    surface: Color(0xFFFFFFFF), // surface/white (screens add SeenBrand.gradientScreen)
    card: Color(0xFFFFFFFF), // surface/card
    surfaceSunken: Color(0xFFF8F6FF), // brand/violet-05
    border: Color(0xFFEEEAF6), // line/default
    borderStrong: Color(0xFFD5CBF7), // line/strong
    ink: Color(0xFF1B1530), // text/ink
    inkSecondary: Color(0xFF5B5280), // text/secondary
    inkMuted: Color(0xFF8A83A8), // text/muted
    inkDisabled: Color(0xFFCABAFB), // brand/violet-40 (disabled button label)
    onPrimary: Color(0xFFFFFFFF), // text/on-brand
    onPrimaryMuted: Color(0xD9FFFFFF), // white @ 85% (balance-card captions)
    primary: Color(0xFF7B52F5), // brand/violet
    primaryHover: Color(0xFF7B52F5), // Pressed = solid violet (default is SeenBrand.gradientCta)
    primarySoft: Color(0xFFF2EEFE), // brand/violet-10
    primaryLine: Color(0xFFD5CBF7), // line/strong
    primaryInk: Color(0xFF6A3FEF), // text/link
    slate: Color(0xFF6A3FEF), // secondary-button label / icon ink = text/link
    accent: Color(0xFF7B52F5), // alias of primary (Figma has no second brand hue)
    accentSoft: Color(0xFFF2EEFE), // alias of primarySoft
    accentInk: Color(0xFF6A3FEF), // alias of primaryInk
    focus: Color(0xFF7B52F5), // focused field border; halo = SeenBrand.focusHalo
    pendingBg: Color(0xFFFFF1D6), // status/action
    pendingFg: Color(0xFF7A4E00),
    pendingLine: Color(0xFFFFF1D6),
    successBg: Color(0xFFE3F4EC), // status/completed
    successFg: Color(0xFF17694A),
    successLine: Color(0xFFE3F4EC),
    dangerBg: Color(0xFFFBE7E9), // status/rejected
    dangerFg: Color(0xFFA3263A),
    dangerLine: Color(0xFFFBE7E9),
    slaBg: Color(0xFFFFE6DA), // status/urgent (deadline < 24h)
    slaFg: Color(0xFFA33A0C),
    slaSolid: Color(0xFFA33A0C),
    scrim: Color(0x7A0F172A), // rgba(15,23,42,0.48)
    sheetShadow: [
      BoxShadow(color: Color(0xFFE2E8F0), offset: Offset(0, -1)),
      BoxShadow(color: Color(0x140F172A), offset: Offset(0, -8), blurRadius: 24), // 8%
    ],
  );

  static const dark = SeenColors(
    surface: Color(0xFF04191D),
    card: Color(0xFF082A30),
    surfaceSunken: Color(0xFF0C3640),
    border: Color(0xFF14505B),
    borderStrong: Color(0xFF1F6C7A),
    ink: Color(0xFFE0F7FA),
    inkSecondary: Color(0xFFA6D9E0),
    inkMuted: Color(0xFF7FB4BE),
    inkDisabled: Color(0xFF4F8089),
    onPrimary: Color(0xFFFFFFFF),
    onPrimaryMuted: Color(0xFFB2EBF2),
    primary: Color(0xFF00838F),
    primaryHover: Color(0xFF0097A7),
    primarySoft: Color(0xFF0C3640),
    primaryLine: Color(0xFF1F6C7A),
    primaryInk: Color(0xFF4DD0E1),
    slate: Color(0xFFB2EBF2),
    accent: Color(0xFF00838F),
    accentSoft: Color(0xFF0C3640),
    accentInk: Color(0xFF80DEEA),
    focus: Color(0xFF4DD0E1),
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

  static SeenColors of(BuildContext context) => Theme.of(context).extension<SeenColors>()!;

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

/// Figma "Seen Violet" brand tokens that have no dark counterpart: the violet
/// ramp (white-ward only), component fills, progress colors and gradients.
/// Prefer the semantic [SeenColors] fields in widgets; use these where Figma
/// names a ramp step or gradient explicitly.
abstract final class SeenBrand {
  // brand/violet ramp
  static const violet05 = Color(0xFFF8F6FF);
  static const violet10 = Color(0xFFF2EEFE);
  static const violet20 = Color(0xFFE5DCFD);
  static const violet40 = Color(0xFFCABAFB);
  static const violet60 = Color(0xFFB097F9);
  static const violet80 = Color(0xFF9575F7);
  static const violet = Color(0xFF7B52F5);
  static const violetLight = Color(0xFF9B7DF8); // gradient/cta end
  static const violetSoft = Color(0xFFC3B0FC); // gradient/card end

  // Component fills (Figma Button / Input / Chip variants)
  static const buttonSecondaryBg = Color(0xFFF3F0FD);
  static const buttonOutlineBorder = Color(0xFFB9A5FF);
  static const buttonDarkBg = Color(0xFF1B1530); // = text/ink
  static const buttonDisabledBg = violet20;
  static const buttonDisabledFg = violet40;
  static const buttonDestructiveBg = Color(0xFFFBE7E9);
  static const buttonDestructiveFg = Color(0xFFA3263A);
  static const buttonDarkPressedBg = Color(0xFF332B4D);
  static const buttonDestructivePressedBg = Color(0xFFF6D3D7);
  static const buttonDestructiveDisabledBg = Color(0x80FBE7E9); // #FBE7E9 @ 50%
  static const buttonDestructiveDisabledFg = Color(0xFFD7A1A9);
  static const inputErrorBorder = Color(0xFFA3263A);
  static const focusHalo = Color(0x297B52F5); // violet @ 16%

  /// Inactive bottom-navigation icon (Figma tab item, Default).
  static const tabIconInactive = Color(0xFFB3ADC8);

  // Progress segments (request cards, wallet usage bar)
  static const progressTodo = Color(0xFFECEAF3);
  static const progressWaiting = Color(0xFFE8B54A);
  static const progressDone = violet;

  // Loading system (design/loading/SPEC.md section 2): only the colours the app had no token for.
  /// Sky gradient of the determinate progress mark.
  static const skyTop = Color(0xFFA68BFF);
  static const skyBottom = Color(0xFF5A36D2);

  /// Skeleton base and sweep highlight; on gradient surfaces use the on-dark pair.
  static const skeletonBase = Color(0xFFECE7FA);
  static const skeletonHighlight = Color(0xBFFFFFFF); // white @ 75%
  static const skeletonOnDarkBase = Color(0x29FFFFFF); // white @ 16%
  static const skeletonOnDarkHighlight = Color(0x47FFFFFF); // white @ 28%

  /// Loader track on gradient or dark surfaces (white @ 22%).
  static const loaderTrackOnDark = Color(0x38FFFFFF);

  /// Label of the refresher while armed («أفلت للتحديث»).
  static const refreshArmedLabel = Color(0xFF2C186A);

  /// The check of a finished refresh.
  static const loaderDone = Color(0xFF2E9E6B);

  /// Scrim of a blocking wait (money or irreversible action): ink @ 60%.
  static const blockingScrim = Color(0x991B1530);

  // Gradients. Figma exports the horizontal ones as "to left" in an RTL
  // layout, i.e. start (right) -> end (left). Directional alignment keeps that
  // look in RTL and mirrors it for LTR.
  static const _start = AlignmentDirectional.centerStart;
  static const _end = AlignmentDirectional.centerEnd;

  /// Primary buttons, selected segments and chips.
  static const gradientCta = LinearGradient(begin: _start, end: _end, colors: [violet, violetLight]);

  /// Balance card, ticket header, bank-details card.
  static const gradientCard = LinearGradient(begin: _start, end: _end, colors: [violet, violetSoft]);

  /// Soft screen wash behind status bar + header (top 340px, violet 10% -> transparent).
  static const gradientScreen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x1A7B52F5), Color(0x00FFFFFF)],
  );

  /// Splash background. Direction not specified in Figma (vertical assumed).
  static const gradientSplash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [violet, Color(0xFFFFFFFF)],
  );

  /// Promo banner, form stepper, profile card.
  static const gradientPromo = LinearGradient(begin: _start, end: _end, colors: [violet20, Color(0xFFFFFFFF)]);

  /// Soft info panels: deadline, help, pending top-up, unread notification.
  static const gradientSoft = LinearGradient(begin: _start, end: _end, colors: [violet10, Color(0xFFFFFFFF)]);

  /// Wallet-hold panel on the review screen.
  static const gradientWalletHold =
      LinearGradient(begin: _start, end: _end, colors: [Color(0xFFDBCDFF), Color(0xFFF5EBFF)]);
}

/// Foreground / background pair of a request status chip.
@immutable
class SeenStatusColors {
  const SeenStatusColors({required this.fg, required this.bg});
  final Color fg;
  final Color bg;
}

/// The 12 request statuses of the Figma "Request statuses" page. Presentation
/// only; deliberately separate from the legacy 5-member [SeenTone] so its
/// exhaustive switches keep compiling.
///
/// Mapping rules (applied by view-models, not here):
///  * [deadlineUnder24h] and [expired] are client-computed from the 72h SLA
///    timestamp, not backend states.
///  * [withAuthority] and [confirmed] have no backend enum value; map them
///    from `RequestStatus.underReview` / `RequestStatus.processing`.
enum SeenRequestStatus {
  newRequest,
  submitted,
  underReview,
  processing,
  withAuthority,
  actionRequired,
  deadlineUnder24h,
  completed,
  confirmed,
  rejected,
  cancelled,
  expired;

  /// Chip colors (≥ 4.5:1). Identical in light and dark: Figma has no dark spec.
  SeenStatusColors get colors => _seenRequestStatusColors[this]!;
}

const Map<SeenRequestStatus, SeenStatusColors> _seenRequestStatusColors = {
  SeenRequestStatus.newRequest: SeenStatusColors(fg: Color(0xFF3D3650), bg: Color(0xFFF5F3FA)),
  SeenRequestStatus.submitted: SeenStatusColors(fg: Color(0xFF3F4BC8), bg: Color(0xFFECEEFE)),
  SeenRequestStatus.underReview: SeenStatusColors(fg: Color(0xFF5A33B6), bg: Color(0xFFEDE7FE)),
  SeenRequestStatus.processing: SeenStatusColors(fg: Color(0xFF4A2FA8), bg: Color(0xFFE8E1FE)),
  SeenRequestStatus.withAuthority: SeenStatusColors(fg: Color(0xFF0A6080), bg: Color(0xFFE1F3FA)),
  SeenRequestStatus.actionRequired: SeenStatusColors(fg: Color(0xFF7A4E00), bg: Color(0xFFFFF1D6)),
  SeenRequestStatus.deadlineUnder24h: SeenStatusColors(fg: Color(0xFFA33A0C), bg: Color(0xFFFFE6DA)),
  SeenRequestStatus.completed: SeenStatusColors(fg: Color(0xFF17694A), bg: Color(0xFFE3F4EC)),
  SeenRequestStatus.confirmed: SeenStatusColors(fg: Color(0xFF0F6157), bg: Color(0xFFE2F5F2)),
  SeenRequestStatus.rejected: SeenStatusColors(fg: Color(0xFFA3263A), bg: Color(0xFFFBE7E9)),
  SeenRequestStatus.cancelled: SeenStatusColors(fg: Color(0xFF4E5462), bg: Color(0xFFEEF0F3)),
  SeenRequestStatus.expired: SeenStatusColors(fg: Color(0xFFFFFFFF), bg: Color(0xFFA3263A)),
};
