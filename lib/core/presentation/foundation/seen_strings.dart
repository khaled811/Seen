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

  /// For code and tests that have a locale but no [BuildContext].
  factory SeenStrings.forLocale(Locale locale) => SeenStrings._(locale.languageCode != 'en');

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

  /// "مارس ٢٠٢٤" / "Mar 2024": month name and year; digits follow [numeral].
  String monthYear(DateTime d) {
    const ar = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${(isArabic ? ar : en)[d.month - 1]} ${numeral(d.year)}';
  }

  /// "ساعتين" / "٢٤ ساعة" / "2 h": a short wait.
  String durationHours(int h) => _t(_arUnit(h, 'ساعة', 'ساعتين', 'ساعات'), '$h h');

  String durationMinutes(int m) => _t(_arUnit(m, 'دقيقة', 'دقيقتين', 'دقائق'), '$m min');

  /// "٣ مسودات" / "3 drafts" (Arabic dual and plural forms).
  String draftCount(int n) {
    if (!isArabic) return n == 1 ? '1 draft' : '$n drafts';
    return switch (n) {
      1 => 'مسودة واحدة',
      2 => 'مسودتان',
      >= 3 && <= 10 => '${numeral(n)} مسودات',
      _ => '${numeral(n)} مسودة',
    };
  }

  /// "قبل ساعتين" / "2 h ago" up to a day, "أمس", then "قبل ٣ أيام" / "3 days ago".
  String draftAge(DateTime at, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final days = DateTime(n.year, n.month, n.day).difference(DateTime(at.year, at.month, at.day)).inDays;
    if (days <= 0) return timeAgo(at, now: n);
    if (days == 1) return _t('أمس', 'Yesterday');
    return _t('قبل ${_arUnit(days, 'يوم', 'يومين', 'أيام')}', '$days days ago');
  }

  /// "تُحذف اليوم" / "تُحذف غدًا" / "تُحذف خلال يومين": when a draft expires.
  String draftDeletesIn(int days) => switch (days) {
        <= 0 => _t('تُحذف اليوم', 'Deleted today'),
        1 => _t('تُحذف غدًا', 'Deleted tomorrow'),
        _ => _t('تُحذف خلال ${_arUnit(days, 'يوم', 'يومين', 'أيام')}', 'Deleted in $days days'),
      };

  /// "٣ نتائج لـ «الحميري»" / "3 results for “q”" (request search, Figma REQ-13).
  String searchResults(int n, String query) {
    if (!isArabic) return '${n == 1 ? '1 result' : '$n results'} for “$query”';
    final head = switch (n) {
      1 => 'نتيجة واحدة',
      2 => 'نتيجتان',
      >= 3 && <= 10 => '${numeral(n)} نتائج',
      _ => '${numeral(n)} نتيجة',
    };
    return '$head لـ «$query»';
  }

  /// "٣ غير مقروءة" / "3 unread" (the notifications header caption).
  String unreadCount(int n) => _t('${numeral(n)} غير مقروءة', '$n unread');

  /// "قبل ١٠ دقائق" / "10 min ago" for the last day, "أمس" for yesterday and a
  /// day-month for anything older. [now] is injectable for tests.
  String timeAgo(DateTime at, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final diff = n.difference(at);
    if (diff.inMinutes < 1) return _t('الآن', 'Just now');
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return _t('قبل ${_arUnit(m, 'دقيقة', 'دقيقتين', 'دقائق')}', '$m min ago');
    }
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(at.year, at.month, at.day);
    final days = today.difference(day).inDays;
    if (days <= 0) {
      final h = diff.inHours;
      return _t('قبل ${_arUnit(h, 'ساعة', 'ساعتين', 'ساعات')}', '$h h ago');
    }
    if (days == 1) return _t('أمس', 'Yesterday');
    return dayMonth(at);
  }

  String _arUnit(int n, String one, String two, String few) => switch (n) {
        1 => one,
        2 => two,
        >= 3 && <= 10 => '${numeral(n)} $few',
        _ => '${numeral(n)} $one',
      };

  /// "تبقّت محاولتان" / "2 attempts left" for the wrong-code message.
  String attemptsLeft(int n) {
    if (!isArabic) return n == 1 ? '1 attempt left' : '$n attempts left';
    return switch (n) {
      1 => 'تبقّت محاولة واحدة',
      2 => 'تبقّت محاولتان',
      >= 3 && <= 10 => 'تبقّت ${numeral(n)} محاولات',
      _ => 'تبقّت ${numeral(n)} محاولة',
    };
  }

  /// m:ss for a countdown; digits stay Latin like other clock values.
  String clockMs(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

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

  // Pickers (Figma BOOK-03 … 06).
  String get optionsSearchHint => _t('ابحث…', 'Search…');
  String get optionsRecent => _t('الأخيرة', 'Recent');
  String get optionsAll => _t('الكل', 'All');
  String optionsNoMatch(String q) => _t('لا نتائج لـ «$q»', 'No results for “$q”');
  String get optionsNoMatchHint => _t('جرّب كتابة الاسم بطريقة أخرى.', 'Try spelling it another way.');
  String expiryRuleHint(int months) => _t('يجب أن تبقى صالحة ${numeral(months)} أشهر على الأقل.', 'Must be valid for at least $months more months.');
  String get dateConfirm => _t('تأكيد التاريخ', 'Confirm date');
  String get dateSelected => _t('التاريخ المحدد', 'Selected date');
  String get attachSourceTitle => _t('إضافة مرفق', 'Add attachment');
  String get attachCamera => _t('الكاميرا', 'Camera');
  String get attachGallery => _t('معرض الصور', 'Photo gallery');
  String get attachFile => _t('ملف', 'File');
  String get attachReplace => _t('استبدال', 'Replace');
  String get attachRemove => _t('حذف المرفق', 'Remove attachment');
  String get attachTypes => _t('الأنواع المقبولة: JPG وPNG وPDF', 'Accepted: JPG, PNG, PDF');
  String attachTooLarge(int mb) => _t('الملف أكبر من ${numeral(mb)} ميغابايت.', 'The file is larger than $mb MB.');
  // System states (Figma SYS-03 / 04 / 05).
  String get forbiddenTitle => _t('ليس لديك صلاحية', 'You do not have permission');
  String get forbiddenWallet => _t(
      'المحفظة متاحة لمالك الحساب فقط. اطلب الصلاحية من مالك الحساب.',
      'The wallet is for the account owner only. Ask the account owner for access.');
  String get requestAccess => _t('طلب الصلاحية', 'Request access');
  String get accessRequestSent => _t('أرسلنا طلبك لمالك الحساب.', 'We sent your request to the account owner.');
  String get accessRequestFailed => _t('تعذّر إرسال الطلب. حاول مرة أخرى.', 'Could not send the request. Try again.');
  String get backToHome => _t('العودة للرئيسية', 'Back to home');
  String get visibilityRule => _t(
      'قاعدة: نخفي الأقسام غير المسموحة في القوائم، ونعطّل الأزرار داخل الشاشات المسموحة مع شرح السبب.',
      'Rule: sections you cannot use are hidden from menus; buttons inside allowed screens are disabled with the reason.');
  String get maintenanceTitle => _t('نُحسّن سين Business الآن', 'We are improving Seen Business');
  String maintenanceBody(DateTime? eta, DateTime now) {
    const safe = ' طلباتك وبياناتك محفوظة.';
    const safeEn = ' Your requests and data are safe.';
    if (eta == null || !eta.isAfter(now)) {
      return _t('صيانة مجدولة. نعود قريبًا.$safe', 'Scheduled maintenance. We will be back soon.$safeEn');
    }
    final minutes = (eta.difference(now).inSeconds / 60).ceil();
    return _t('صيانة مجدولة. نعود خلال ${_arUnit(minutes, 'دقيقة', 'دقيقتين', 'دقائق')} تقريبًا (حتى ${clock12(eta)}).$safe',
        'Scheduled maintenance. Back in about $minutes min (until ${clock12(eta)}).$safeEn');
  }
  String maintenanceEtaChip(DateTime eta) => _t('الوقت المتوقع · ${clock24(eta)}', 'Expected · ${clock24(eta)}');
  String get retryAction => _t('إعادة المحاولة', 'Try again');
  String get updateRequiredTitle => _t('تحديث مطلوب', 'Update required');
  String get updateRequiredBody => _t('هذا الإصدار لم يعد مدعومًا. حدّث التطبيق للمتابعة بأمان.',
      'This version is no longer supported. Update the app to continue safely.');
  String get updateFromStore => _t('تحديث من المتجر', 'Update from the store');
  String get updateOptionalTitle => _t('تحديث اختياري متاح', 'Optional update available');
  String updateVersionLine(String version, String? note) =>
      _t('الإصدار $version', 'Version $version') + (note == null || note.isEmpty ? '' : ' · $note');
  String get updateLater => _t('لاحقًا', 'Later');
  String get updateNow => _t('تحديث', 'Update');
  String get storeUnavailable => _t('تعذّر فتح المتجر.', 'Could not open the store.');

  /// "02:30" (24 h, Latin digits).
  String clock24(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// "02:30 ص" / "2:30 AM".
  String clock12(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final pm = d.hour >= 12;
    return isArabic ? '${h.toString().padLeft(2, '0')}:$m ${pm ? 'م' : 'ص'}' : '$h:$m ${pm ? 'PM' : 'AM'}';
  }

  String get attachUnavailable => _t('تعذّر فتح المصدر. تحقق من أذونات التطبيق.', 'Could not open the source. Check the app permissions.');
  String get attachBadType => _t('نوع الملف غير مقبول. استخدم JPG أو PNG أو PDF.', 'File type not accepted. Use JPG, PNG or PDF.');
  String get attachNotSent => _t('المرفق محفوظ على جهازك فقط ولم يُرسل بعد.', 'The attachment is kept on this device and has not been sent yet.');
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

  /// "مسافر ٣" / "Traveler 3": the label of a switcher tile.
  String travelerShort(int n) => _t('مسافر ${numeral(n)}', 'Traveler $n');
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
