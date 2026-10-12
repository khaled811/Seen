// Icon set: Phosphor Regular (1.5px-equivalent outline, round caps) via phosphor_flutter.
// Every component references SeenIcons, so swapping the icon family is one file.
//
// Migrated verbatim from design_export/ — every icon name below was checked
// against the installed phosphor_flutter 2.1.0 package (not assumed) and
// all resolved.
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

abstract final class SeenIcons {
  static IconData get bell => PhosphorIcons.bell();
  static IconData get globe => PhosphorIcons.globe();
  static IconData get plus => PhosphorIcons.plus();
  static IconData get shield => PhosphorIcons.shieldCheck();
  static IconData get radar => PhosphorIcons.crosshair();
  static IconData get file => PhosphorIcons.fileText();
  static IconData get users => PhosphorIcons.users();
  static IconData get headset => PhosphorIcons.headset();
  static IconData get wallet => PhosphorIcons.wallet();
  static IconData get clock => PhosphorIcons.clock();
  static IconData get check => PhosphorIcons.check(PhosphorIconsStyle.bold);
  static IconData get x => PhosphorIcons.x();
  static IconData get download => PhosphorIcons.downloadSimple();
  static IconData get credit => PhosphorIcons.arrowDownLeft(PhosphorIconsStyle.bold); // money in — never mirrored
  static IconData get debit => PhosphorIcons.arrowUpRight(PhosphorIconsStyle.bold); // money out — never mirrored
  static IconData get lock => PhosphorIcons.lock();
  static IconData get home => PhosphorIcons.house();
  static IconData get list => PhosphorIcons.list();
  static IconData get bank => PhosphorIcons.bank();
  static IconData get exchange => PhosphorIcons.arrowsLeftRight();
  static IconData get cash => PhosphorIcons.money();
  static IconData get alert => PhosphorIcons.warning();
  static IconData get info => PhosphorIcons.info();
  static IconData get search => PhosphorIcons.magnifyingGlass();
  static IconData get user => PhosphorIcons.user();
  static IconData get calendar => PhosphorIcons.calendarBlank();
  static IconData get building => PhosphorIcons.buildings();
  static IconData get passport => PhosphorIcons.identificationCard();
  static IconData get more => PhosphorIcons.dotsThree();
  static IconData get copy => PhosphorIcons.copy();
  static IconData get send => PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.bold);
  static IconData get eye => PhosphorIcons.eye();
  static IconData get eyeSlash => PhosphorIcons.eyeSlash();
  static IconData get refresh => PhosphorIcons.arrowsClockwise();

  /// Chevron pointing "back" in the current reading direction.
  static IconData back(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl ? PhosphorIcons.caretRight() : PhosphorIcons.caretLeft();

  /// Chevron pointing "forward" in the current reading direction.
  static IconData forward(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl ? PhosphorIcons.caretLeft() : PhosphorIcons.caretRight();
}
