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
