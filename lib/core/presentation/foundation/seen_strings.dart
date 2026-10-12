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
