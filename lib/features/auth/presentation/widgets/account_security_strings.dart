// Copy for changing the password and the phone number (Figma AUTH-15 / 16).
import '../../../../core/presentation/foundation/seen_strings.dart';

extension AccountSecurityStrings on SeenStrings {
  String _t(String ar, String en) => isArabic ? ar : en;

  // ── AUTH-15 ──
  String get changePasswordTitle => _t('تغيير كلمة المرور', 'Change password');
  String get currentPasswordLabel => _t('كلمة المرور الحالية', 'Current password');
  String get newPasswordLabel => _t('كلمة المرور الجديدة', 'New password');
  String get confirmPasswordLabel => _t('تأكيد كلمة المرور', 'Confirm password');
  String get passwordRulesHelper =>
      _t('٨ أحرف على الأقل، حرف كبير وحرف صغير، ورقم.', 'At least 8 characters, an upper and a lower case letter, and a digit.');
  String get savePassword => _t('حفظ', 'Save');
  String get wrongCurrentPassword => _t('كلمة المرور الحالية غير صحيحة', 'The current password is not correct');
  String get passwordsDoNotMatch => _t('كلمتا المرور غير متطابقتين', 'The passwords do not match');
  String get passwordReusedBanner => _t('لا يمكن استخدام كلمة مرور سابقة.', 'You cannot reuse a previous password.');
  String get passwordWeakBanner => _t('كلمة المرور ضعيفة. اتبع القواعد أعلاه.', 'The password is too weak. Follow the rules above.');
  String get passwordChanged =>
      _t('تم تغيير كلمة المرور. سنُخرجك من الأجهزة الأخرى.', 'Password changed. We will sign you out of your other devices.');
  String get accountOffline => _t('لا يوجد اتصال. حاول مرة أخرى.', 'No connection. Try again.');
  String get accountGeneric => _t('حدث خطأ. حاول مرة أخرى.', 'Something went wrong. Try again.');

  // ── AUTH-16 ──
  String get changePhoneTitle => _t('تغيير رقم الجوال', 'Change mobile number');
  String get currentNumberLabel => _t('الرقم الحالي', 'Current number');
  String get newNumberLabel => _t('الرقم الجديد', 'New number');
  String get enterNewNumberCode => _t('أدخل الرمز المرسل إلى الرقم الجديد', 'Enter the code sent to the new number');
  String get confirmNumber => _t('تأكيد الرقم', 'Confirm number');
  String get phoneTakenBanner => _t('الرقم الجديد مستخدم في حساب آخر.', 'The new number is used by another account.');
  String phoneCodeWrong(int left) => _t('الرمز غير صحيح. ${attemptsLeft(left)}.', 'The code is not correct. ${attemptsLeft(left)}.');
  String get phoneCodeExpired => _t('انتهت صلاحية الرمز.', 'The code has expired.');
  String phoneCodeLocked(int minutes) =>
      _t('تجاوزت عدد المحاولات. حاول بعد ${numeral(minutes)} دقيقة.', 'Too many attempts. Try again in $minutes minutes.');
  String phoneRateLimited(int seconds) =>
      _t('انتظر ${clockMs(seconds)} قبل طلب رمز جديد.', 'Wait ${clockMs(seconds)} before asking for a new code.');
  String get phoneChanged =>
      _t('تم تغيير رقم الجوال. استخدم الرقم الجديد عند تسجيل الدخول.', 'Mobile number changed. Use the new number to sign in.');
  String get resendCodeIn => _t('إعادة الإرسال بعد', 'Resend in');
  String get resendNow => _t('إعادة إرسال الرمز', 'Resend the code');
}
