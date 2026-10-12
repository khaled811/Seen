// Seen Booking design system -- money & BiDi helpers.
// Latin digits, 2 decimals, "USD" code, always a left-to-right run.

import 'package:intl/intl.dart';

abstract final class SeenFormat {
  static final _money = NumberFormat('#,##0.00', 'en_US');

  /// "12,480.00"
  static String money(num v) => _money.format(v);

  /// "+5,000.00" / "−270.00" (true minus sign U+2212).
  static String signed(num v, {required bool credit}) => '${credit ? '+' : '−'}${money(v)}';

  /// e.g. "270.00 USD", wrapped via [isolate] so this run is never reordered
  /// when embedded inside Arabic (RTL) text.
  static String usd(num v) => isolate('${money(v)} USD');

  /// Wraps any LTR run (amount, date, phone, reference) in the Unicode
  /// Left-to-Right Isolate / Pop Directional Isolate control characters.
  /// Deliberate, not stray/hidden text — hence the ignore.
  // ignore: text_direction_code_point_in_literal, text_direction_code_point_in_comment
  static String isolate(String ltr) => '⁦$ltr⁩';

  /// "27/09/2026" and "14:20" (Latin digits in both locales)
  static String date(DateTime d) => DateFormat('dd/MM/yyyy', 'en_US').format(d);
  static String time(DateTime d) => DateFormat('HH:mm', 'en_US').format(d);

  /// Whole months of passport validity left after [from] (the travel date).
  static int monthsBetween(DateTime from, DateTime to) {
    var m = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) m -= 1;
    return m;
  }
}
