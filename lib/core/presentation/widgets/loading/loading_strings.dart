import '../../foundation/seen_strings.dart';

/// Copy of the loading system (refresher, slow and timeout states, blocking wait).
extension LoadingStrings on SeenStrings {
  String _t(String ar, String en) => isArabic ? ar : en;

  String get refreshPull => _t('اسحب للتحديث', 'Pull to refresh');
  String get refreshArmed => _t('أفلت للتحديث', 'Release to refresh');
  String get refreshLoading => _t('جاري التحديث…', 'Refreshing…');
  String get refreshDone => _t('تم التحديث', 'Updated');

  String get slowTitle => _t('الاتصال بطيء', 'Slow connection');
  String slowBanner(int seconds) =>
      _t('ما زلنا نحاول (${numeral(seconds)} ث)', 'still trying (${seconds}s)');
  String get waitCancel => _t('إلغاء', 'Cancel');

  String get timeoutTitle => _t('تعذّر التحميل', 'Could not load');
  String timeoutBody(int seconds) => _t(
        'انتهت مهلة الاتصال بعد ${numeral(seconds)} ثانية. تحقق من الاتصال وحاول مرة أخرى.',
        'The connection timed out after $seconds seconds. Check your connection and try again.',
      );

  String get submittingRequest =>
      _t('جاري إرسال الطلب…', 'Sending the request…');
  String get submittingTopUp =>
      _t('جاري إرسال طلب الشحن…', 'Sending the top-up request…');
  String get submittingTransfer =>
      _t('جاري تنفيذ التحويل…', 'Making the transfer…');
  String get submittingSubAgent =>
      _t('جاري إنشاء الوكيل…', 'Creating the agent…');

  String get doNotCloseApp => _t('لا تغلق التطبيق حتى تكتمل العملية',
      'Do not close the app until it finishes');
}
