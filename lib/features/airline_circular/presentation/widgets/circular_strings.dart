import '../../../../core/presentation/foundation/seen_strings.dart';
import '../bloc/airline_circular_cubit.dart';

/// Copy of the airline circular screens (Figma REQ-15, REQ-15b).
extension CircularStrings on SeenStrings {
  String _t(String ar, String en) => isArabic ? ar : en;

  String get circularTitle => _t('تعميم شركة طيران', 'Airline circular');
  String get circularEntrySubtitle => _t(
      'اربطه بموافقة أمنية صادرة وأرفق التذكرة',
      'Link it to an issued security approval and attach the ticket');
  String linkedTo(String reference) =>
      _t('مرتبط بـ $reference', 'Linked to $reference');

  // --- picker (REQ-15) ---
  String get pickApprovalTitle =>
      _t('اختر الموافقة الأمنية', 'Choose the security approval');
  String get pickApprovalCaption => _t('التعميم يُربط بموافقة أمنية صادرة فقط',
      'A circular is linked to an issued security approval only');
  String get approvalSearchHint =>
      _t('رقم الطلب أو اسم المسافر', 'Request number or traveler name');
  String approvalTitle(String reference) =>
      _t('موافقة أمنية · $reference', 'Security approval · $reference');
  String approvalLine(String lead, int count) =>
      '$lead · ${circularTravelers(count)}';
  String approvalIssued(DateTime d) =>
      _t('صدرت ${dayMonth(d)}', 'Issued ${dayMonth(d)}');
  String get linkAndContinue => _t('ربط ومتابعة', 'Link and continue');
  String get noApprovals => _t('لا توجد موافقات أمنية صادرة بعد.',
      'There is no issued security approval yet.');
  String get noApprovalMatches =>
      _t('لا توجد موافقة تطابق بحثك.', 'No approval matches your search.');
  String get approvalsLoadFailed =>
      _t('تعذّر تحميل الموافقات.', 'Could not load the approvals.');

  String circularTravelers(int n) {
    if (!isArabic) return n == 1 ? '1 traveler' : '$n travelers';
    return switch (n) {
      1 => 'مسافر واحد',
      2 => 'مسافران',
      >= 3 && <= 10 => '${numeral(n)} مسافرين',
      _ => '${numeral(n)} مسافرًا',
    };
  }

  // --- form (REQ-15b) ---
  String linkedApproval(String reference) => _t(
      'موافقة أمنية صادرة · $reference',
      'Issued security approval · $reference');
  String get travelersFilled => _t('بيانات المسافرين معبّأة تلقائيًا',
      'Traveler details are filled in automatically');
  String get changeAction => _t('تغيير', 'Change');
  String get travelerField => _t('المسافر', 'Traveler');
  String get passportField => _t('رقم الجواز', 'Passport number');
  String get lockedFieldsNote => _t(
      'الحقول أعلاه مقفلة لأنها من الموافقة الأصلية.',
      'The fields above are locked because they come from the original approval.');
  String get ticketTitle =>
      _t('أرفق تذكرة الطيران', 'Attach the flight ticket');
  String get ticketCaption => _t('المستند الوحيد المطلوب · PDF أو صورة',
      'The only document needed · PDF or image');
  String get ticketRequired =>
      _t('أرفق تذكرة الطيران.', 'Attach the flight ticket.');
  String get flightNumberLabel => _t('رقم الرحلة', 'Flight number');
  String get flightNumberHint => _t('مثال: RJ 615', 'e.g. RJ 615');
  String get flightNumberInvalid => _t('اكتب رقم رحلة صحيحًا مثل RJ 615.',
      'Enter a valid flight number such as RJ 615.');
  String get flightDateLabel => _t('تاريخ الرحلة', 'Flight date');
  String get flightDateRequired =>
      _t('اختر تاريخ الرحلة.', 'Choose the flight date.');
  String get flightDatePast => _t('تاريخ الرحلة يجب أن يكون اليوم أو بعده.',
      'The flight date must be today or later.');
  String get flightDateRule => _t('اليوم أو بعده', 'Today or later');
  String get sendCircular => _t('إرسال التعميم', 'Send the circular');
  String get circularSent => _t('أُرسل التعميم.', 'The circular was sent.');
  String get circularFailed => _t('تعذّر إرسال التعميم. حاول مرة أخرى.',
      'Could not send the circular. Try again.');
  String get circularPrefillFailed => _t(
      'تعذّر تحميل بيانات الموافقة.', 'Could not load the approval details.');

  String ticketError(TicketError e) => switch (e) {
        TicketError.tooLarge => attachTooLarge(5),
        TicketError.wrongType => attachBadType,
        TicketError.unavailable ||
        TicketError.cameraDenied ||
        TicketError.photosDenied =>
          attachUnavailable,
      };
}
