// Seen Booking design system — color tokens.
// Source: "Seen Booking" design system (tokens.json v1: light + dark).
//
// Rule: FILL -> primary / accent.  TEXT, ICON, BORDER, RING -> primaryInk / accentInk.

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

  static const light = SeenColors(
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
