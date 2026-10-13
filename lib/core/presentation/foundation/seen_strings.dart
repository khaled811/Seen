// Built-in component strings (Arabic default, English), mirroring the web bundle's
// dictionary. Screen copy belongs in your ARB files; this covers only what the
// components render on their own.
//
// WARNING (audit note, not silently reconciled): this is a second,
// self-contained i18n dictionary, separate from this app's ARB-based
// `AppLocalizations`. Kept deliberately, not merged into ARB — these are the
// *default* strings for a portable "Seen" component library that could be
// dropped into another app; hard-wiring it to this app's generated
// `AppLocalizations` would defeat that portability. The tradeoff: if this
// app's Arabic/English wording for a shared concept (e.g. "Approved") ever
// needs to change, it must be updated here too, independently of the ARB
// files. Flag if you'd rather these be reconciled into ARB instead.
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../theme/seen_colors.dart';
import '../../utils/latin_digits.dart';

class SeenStrings {
  const SeenStrings._(this.isArabic);

  final bool isArabic;

  static SeenStrings of(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar';
    return SeenStrings._(code != 'en');
  }

  String _t(String ar, String en) => isArabic ? ar : en;

  // Status vocabulary (fixed — never invent synonyms)
  String get review => _t('قيد المراجعة', 'Under review');
  String get pending => _t('بانتظار الموافقة', 'Awaiting approval');
  String get hold => _t('محجوز', 'On hold');
  String get action => _t('مطلوب إجراء', 'Action required');
  String get rejected => _t('مرفوض', 'Rejected');
  String get completed => _t('مكتمل', 'Completed');
  String get approved => _t('معتمد', 'Approved');
  String get posted => _t('مُرحّل', 'Posted');

  // Numerals: counts and dates use Arabic-Indic digits in Arabic and Latin
  // in English. Money, references, phone numbers and clock times stay Latin
  // (see SeenFormat).
  String numeral(int v) {
    final latin = NumberFormat('#,##0', 'en').format(v);
    return isArabic ? toArabicIndicDigits(latin) : latin;
  }

  /// "١٢ نوفمبر" / "12 Nov": day and month name; digits follow [numeral].
  String dayMonth(DateTime d) {
    const ar = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${numeral(d.day)} ${(isArabic ? ar : en)[d.month - 1]}';
  }

  /// Home greeting line: how many requests need follow-up today.
  String attentionSummary(int n) {
    if (isArabic) {
      return switch (n) {
        0 => 'لا توجد طلبات تحتاج متابعة اليوم',
        1 => 'لديك طلب واحد يحتاج متابعة اليوم',
        2 => 'لديك طلبان يحتاجان متابعة اليوم',
        >= 3 && <= 10 => 'لديك ${numeral(n)} طلبات تحتاج متابعة اليوم',
        _ => 'لديك ${numeral(n)} طلبًا تحتاج متابعة اليوم',
      };
    }
    return switch (n) {
      0 => 'No requests need follow-up today',
      1 => '1 request needs follow-up today',
      _ => '$n requests need follow-up today',
    };
  }

  /// Traveler count on a request card.
  String travelerCount(int n) {
    if (isArabic) {
      return switch (n) {
        1 => 'مسافر واحد',
        2 => 'مسافران',
        >= 3 && <= 10 => '${numeral(n)} مسافرين',
        _ => '${numeral(n)} مسافرًا',
      };
    }
    return n == 1 ? '1 traveler' : '$n travelers';
  }

  // Request status chips (Figma "Request statuses" — 12 states)
  String requestStatus(SeenRequestStatus s) => switch (s) {
        SeenRequestStatus.newRequest => _t('طلب جديد', 'New request'),
        SeenRequestStatus.submitted => _t('مُرسل', 'Submitted'),
        SeenRequestStatus.underReview => _t('قيد المراجعة', 'Under review'),
        SeenRequestStatus.processing => _t('قيد المعالجة', 'Processing'),
        SeenRequestStatus.withAuthority => _t('لدى الجهة المختصة', 'With authority'),
        SeenRequestStatus.actionRequired => _t('بانتظار مستند', 'Action required'),
        SeenRequestStatus.deadlineUnder24h => _t('أقل من ٢٤ ساعة', 'Under 24 hours'),
        SeenRequestStatus.completed => _t('مكتمل', 'Completed'),
        SeenRequestStatus.confirmed => _t('مؤكدة', 'Confirmed'),
        SeenRequestStatus.rejected => _t('مرفوض', 'Rejected'),
        SeenRequestStatus.cancelled => _t('ملغي', 'Cancelled'),
        SeenRequestStatus.expired => _t('انتهت المهلة', 'Expired'),
      };

  // Request progress (5 steps shown on request cards)
  String requestStep(int step) => switch (step) {
        1 => _t('استلام الطلب', 'Request received'),
        2 => _t('مراجعة المستندات', 'Reviewing documents'),
        3 => _t('لدى الجهة المختصة', 'With the authority'),
        4 => _t('إصدار الموافقة', 'Issuing approval'),
        _ => _t('صادرة', 'Issued'),
      };
  String stepOf(int step, int total) =>
      _t('${numeral(step)} من ${numeral(total)}', '$step of $total');

  /// The five stepper stage names on request tracking (the last one is the
  /// delivery stage; [requestStep] words it as the issued state for cards).
  String requestStepTitle(int step) => step == 5 ? _t('التسليم', 'Delivery') : requestStep(step);

  /// Action-required banner headline on the requests dashboard.
  String actionBannerTitle(int n) {
    if (isArabic) {
      return switch (n) {
        1 => 'طلب بانتظار مستند',
        2 => 'طلبان بانتظار مستندات',
        >= 3 && <= 10 => '${numeral(n)} طلبات بانتظار مستندات',
        _ => '${numeral(n)} طلبًا بانتظار مستندات',
      };
    }
    return n == 1 ? '1 request awaiting documents' : '$n requests awaiting documents';
  }

  /// Booking flow: "Step 2 of 3", "Traveler 1 of 3", "Service fee × 3".
  String bookingStep(int n, int total) =>
      _t('الخطوة ${numeral(n)} من ${numeral(total)}', 'Step $n of $total');
  String travelerOf(int n, int total) =>
      _t('المسافر ${numeral(n)} من ${numeral(total)}', 'Traveler $n of $total');
  String serviceFeeTimes(int n) => _t('رسوم الخدمة × ${numeral(n)}', 'Service fee × $n');

  /// Compact remaining time "46:12 س" / "46:12 h".
  String clockHm(int h, int m) {
    final text = '$h:${m.toString().padLeft(2, '0')}';
    return isArabic ? '${toArabicIndicDigits(text)} س' : '$text h';
  }

  // Deadline countdown pill
  String remainingHours(int h) => _t('يتبقى ${numeral(h)} ساعة', '$h h left');
  String remainingMinutes(int m) => _t('يتبقى ${numeral(m)} دقيقة', '$m min left');

  // SLA
  String get slaExceeded => _t('تجاوز المهلة', 'SLA exceeded');
  String hours(int h) => _t('$h ساعة', '$h hours');
  String hoursMinutes(int h, int m) => _t('$hس $mد', '${h}h ${m}m');
  String ofTotal(int h) => _t('من $h', 'of $h');
  String get slaLeft => _t('الوقت المتبقي من مهلة المعالجة', 'Time left in the processing SLA');

  // Chrome
  String get back => _t('رجوع', 'Back');
  String get close => _t('إغلاق', 'Close');
  String get notifications => _t('الإشعارات', 'Notifications');
  String get languageSwitch => _t('EN', 'ع');
  String get languageLabel => _t('English', 'العربية');
  List<String> get nav => isArabic
      ? const ['الرئيسية', 'طلباتي', 'المحفظة', 'الوكلاء', 'حسابي']
      : const ['Home', 'Requests', 'Wallet', 'Agents', 'Account'];

  // Wallet
  String get availableBalance => _t('الرصيد المتاح', 'Available balance');
  String get topUp => _t('شحن الرصيد', 'Top up');
  String get onHold => _t('محجوز', 'On hold');
  String get total => _t('الإجمالي', 'Total');
  String get creditLimit => _t('حد الائتمان', 'Credit limit');

  // Booking
  String get pricePerTraveler => _t('السعر لكل مسافر', 'Price per traveler');
  String get processing => _t('مدة المعالجة', 'Processing');
  String get documents => _t('المستندات', 'Documents');
  String traveler(int n) => _t('المسافر $n', 'Traveler $n');
  String get addTraveler => _t('إضافة مسافر', 'Add traveler');
  String travelers(int n) => _t('$n مسافرين', n == 1 ? '1 traveler' : '$n travelers');
  String get validityBad =>
      _t('الصلاحية أقل من 6 أشهر — لن يُقبل الطلب', 'Less than 6 months valid — the request will be rejected');
  String validityMid(int m) =>
      _t('الصلاحية $m أشهر — مقبول، يُنصح بالتجديد قريبًا', 'Valid $m months — accepted, renewal advised');
  String validityOk(int m) => _t('الصلاحية $m شهرًا — مستوفٍ لشرط 6 أشهر', 'Valid $m months — meets the 6-month rule');
  String get totalToHold => _t('الإجمالي المطلوب حجزه', 'Total to hold');
  String get balanceEnough => _t('الرصيد كافٍ لإتمام الحجز', 'Balance covers this booking');
  String get balanceNotEnough => _t('الرصيد غير كافٍ', 'Insufficient balance');
  String get availableShort => _t('المتاح', 'Available');
  String get afterBooking => _t('بعد الحجز', 'After booking');

  // Sub-agents
  String get service => _t('الخدمة', 'Service');
  String get travelersLabel => _t('المسافرون', 'Travelers');
  String get amount => _t('المبلغ', 'Amount');
  String get branchMargin => _t('هامش الفرع', 'Branch margin');
  String get reject => _t('رفض', 'Reject');
  String get approve => _t('اعتماد', 'Approve');
  String get suspended => _t('موقوف', 'Suspended');
  String users(int n) => _t('$n مستخدمين', n == 1 ? '1 user' : '$n users');
  String margin(String v) => _t('هامش $v', 'Margin $v');
  String get balance => _t('الرصيد', 'Balance');

  // Sign-in / feedback
  String get otpLabel => _t('رمز التحقق', 'Verification code');
  String get unread => _t('غير مقروء', 'Unread');
}
