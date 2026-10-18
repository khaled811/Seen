import '../../../../core/presentation/foundation/seen_strings.dart';
import '../bloc/manifest_build_cubit.dart';
import '../bloc/manifest_summary_cubit.dart';

/// Copy of the group manifest screens (Figma REQ-14, REQ-14b).
extension ManifestStrings on SeenStrings {
  String _t(String ar, String en) => isArabic ? ar : en;

  // --- build (REQ-14) ---
  String get manifestTitle => _t('كشف جماعي', 'Group manifest');
  String get openGroupManifest =>
      _t('فتح الكشف الجماعي', 'Open the group manifest');
  String get importListTitle =>
      _t('استيراد قائمة المسافرين', 'Import the traveler list');
  String get importListCaption => _t(
      'Excel أو CSV · قالب جاهز للتنزيل', 'Excel or CSV · ready-made template');
  String get importAction => _t('استيراد', 'Import');
  String get addTravelerAction => _t('إضافة مسافر', 'Add a traveler');
  String get saveAsDraft => _t('حفظ كمسودة', 'Save as draft');
  String get reviewManifest => _t('مراجعة الكشف', 'Review the manifest');
  String get manifestLoadFailed =>
      _t('تعذّر تحميل الكشف.', 'Could not load the manifest.');

  String travelersCount(int n) {
    if (!isArabic) return n == 1 ? '1 traveler' : '$n travelers';
    return switch (n) {
      1 => 'مسافر واحد',
      2 => 'مسافران',
      >= 3 && <= 10 => '${numeral(n)} مسافرين',
      _ => '${numeral(n)} مسافرًا',
    };
  }

  String completeChip(int n) => _t('${numeral(n)} مكتمل', '$n complete');
  String incompleteChip(int n) => _t('${numeral(n)} ناقص', '$n incomplete');
  String moreTravelers(int n) =>
      _t('+ ${numeral(n)} مسافرين آخرين', '+ $n more travelers');
  String get showFewer => _t('عرض أقل', 'Show fewer');

  String get travelerReady => _t('جاهز', 'Ready');
  String get missingPassport => _t('ينقص الجواز', 'Passport missing');
  String passportExpiresIn(int? months) {
    if (months == null) {
      return _t('الجواز ينتهي قريبًا', 'Passport expires soon');
    }
    final unit = !isArabic
        ? (months == 1 ? '1 month' : '$months months')
        : switch (months) {
            1 => 'شهر واحد',
            2 => 'شهرين',
            >= 3 && <= 10 => '${numeral(months)} أشهر',
            _ => '${numeral(months)} شهرًا',
          };
    return _t('الجواز ينتهي خلال $unit', 'Passport expires within $unit');
  }

  // Add a traveler
  String get travelerNameLabel => _t('اسم المسافر', 'Traveler name');
  String get passportNumberOptional =>
      _t('رقم الجواز (اختياري)', 'Passport number (optional)');
  String get travelerNameRequired =>
      _t('اكتب اسم المسافر.', 'Enter the traveler name.');

  // Review before sending
  String get sendManifestTitle => _t('إرسال الكشف', 'Send the manifest');
  String sendManifestBody(int ready, int incomplete) => incomplete == 0
      ? _t('سيُرسل الكشف بـ ${travelersCount(ready)}.',
          'The manifest will be sent with ${travelersCount(ready)}.')
      : _t(
          'سيُرسل الجاهزون (${numeral(ready)}). أما الناقصون (${numeral(incomplete)}) فلن يُرسلوا حتى تكتمل بياناتهم.',
          'The $ready ready travelers will be sent. The $incomplete incomplete ones will not be sent until completed.');
  String get nothingToSend => _t(
      'لا يوجد مسافر جاهز للإرسال بعد.', 'No traveler is ready to send yet.');
  String get sendManifestAction => _t('إرسال الكشف', 'Send the manifest');

  String manifestNotice(ManifestNotice n) => switch (n) {
        ManifestNotice.saved =>
          _t('حُفظ الكشف كمسودة.', 'The manifest was saved as a draft.'),
        ManifestNotice.added => _t('أُضيف المسافر.', 'The traveler was added.'),
        ManifestNotice.imported =>
          _t('استُوردت القائمة.', 'The list was imported.'),
        ManifestNotice.importTooLarge =>
          _t('الملف أكبر من ٥ ميغابايت.', 'The file is larger than 5 MB.'),
        ManifestNotice.importFailed =>
          _t('تعذّر استيراد الملف.', 'Could not import the file.'),
        ManifestNotice.failed => _t('تعذّر إكمال العملية. حاول مرة أخرى.',
            'That did not work. Try again.'),
      };

  // --- summary (REQ-14b) ---
  String get manifestSummaryTitle => _t('ملخص الكشف', 'Manifest summary');
  String get statusIssued => _t('صادرة', 'Issued');
  String get statusAtAuthority => _t('لدى الجهة', 'With the authority');
  String get statusRejected => _t('مرفوض', 'Rejected');
  String get manifestProcessing => _t('قيد المعالجة', 'Processing');
  String get manifestCompleted => _t('مكتمل', 'Completed');
  String get independentStatusNote => _t(
      'كل مسافر له حالة مستقلة. المرفوض لا يوقف بقية الكشف.',
      'Each traveler has their own status. A rejection does not stop the rest.');
  String rejectionReason(String reason) =>
      _t('السبب: $reason', 'Reason: $reason');
  String get resubmitAction => _t('إعادة التقديم', 'Submit again');
  String downloadIssued(int n) => _t(
      'تنزيل التأشيرات الصادرة (${numeral(n)})', 'Download issued visas ($n)');
  String get summaryLoadFailed =>
      _t('تعذّر تحميل الملخص.', 'Could not load the summary.');

  String summaryNotice(ManifestSummaryNotice n) => switch (n) {
        ManifestSummaryNotice.resubmitted =>
          _t('أُعيد تقديم المسافر.', 'The traveler was submitted again.'),
        ManifestSummaryNotice.downloadFailed =>
          _t('تعذّر تنزيل التأشيرات.', 'Could not download the visas.'),
        ManifestSummaryNotice.failed => _t(
            'تعذّر إكمال العملية. حاول مرة أخرى.',
            'That did not work. Try again.'),
      };
}
