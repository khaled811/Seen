// Seen Booking design system — spacing, radius, sizes (4px base).

import 'package:flutter/material.dart';

abstract final class SeenSpace {
  static const double s1 = 4; // icon-label gap, badge vertical
  static const double s2 = 8; // chip gaps, label-to-field gap
  static const double s3 = 12; // between stacked cards / rows
  static const double s4 = 16; // card padding, screen gutter
  static const double s5 = 20; // field-to-field rhythm
  static const double s6 = 24; // section spacing
  static const double s8 = 32; // section break, sheet top padding
  static const double s10 = 40; // above sticky ActionBar content
  static const gutter = EdgeInsetsDirectional.symmetric(horizontal: s4);
}

abstract final class SeenRadius {
  static const xs = Radius.circular(4); // badges, tags
  static const sm = Radius.circular(8); // buttons, fields, chips, icon tiles
  static const md = Radius.circular(12); // cards
  static const lg = Radius.circular(16); // wallet card, sheet top corners
  static const full = Radius.circular(999); // pill chips, counts

  // Figma radii (Mobile App). `lg` (16) is also the Figma M button / input /
  // OTP box radius. Legacy xs/sm/md above are kept so existing widgets keep
  // compiling until they are migrated to these values.
  static const r14 = Radius.circular(14); // S button, icon tiles
  static const r18 = Radius.circular(18); // service tiles, stats, banners
  static const r20 = Radius.circular(20); // L button, agent rows
  static const r22 = Radius.circular(22); // cards, request card
  static const r24 = Radius.circular(24); // balance / bank-details card
  static const r28 = Radius.circular(28); // ticket
}

/// Figma elevations (shadow colors are the brand-tinted 2C186A / 5B36DA).
abstract final class SeenShadows {
  /// Cards, tiles, icon buttons: `0 4 8 rgba(44,24,106,.06)`.
  static const card = [
    BoxShadow(color: Color(0x0F2C186A), offset: Offset(0, 4), blurRadius: 8),
  ];

  /// Sticky bottom action bar. Casts upward onto the scrolling content (the
  /// Figma value is a downward `0 12 16 .12`, which would fall off-screen;
  /// direction corrected per design-lead decision).
  static const stickyBar = [
    BoxShadow(color: Color.fromRGBO(44, 24, 106, 0.08), offset: Offset(0, -4), blurRadius: 16),
  ];

  /// Balance / bank-details card.
  static const balanceCard = [
    BoxShadow(color: Color(0x1A2C186A), offset: Offset(0, 8), blurRadius: 16, spreadRadius: -6),
    BoxShadow(color: Color(0x4D5B36DA), offset: Offset(0, 24), blurRadius: 48, spreadRadius: -12),
  ];

  /// Request ticket and the extended FAB.
  static const ticket = [
    BoxShadow(color: Color(0x1A2C186A), offset: Offset(0, 8), blurRadius: 16),
    BoxShadow(color: Color(0x4D5B36DA), offset: Offset(0, 24), blurRadius: 48),
  ];
}

abstract final class SeenSize {
  static const double hairline = 1;
  static const double touchMin = 48;
  static const double field = 52; // theme-level InputDecoration minimum height
  static const double input = 54; // Figma input (SeenTextField)
  static const double button = 52;
  static const double buttonSm = 40;
  static const double buttonL = 58; // Figma L button (primary CTA on welcome/login)
  static const double buttonXs = 32; // Figma XS pill button
  static const double appBar = 56;
  static const double bottomNav = 64;
}
