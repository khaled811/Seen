// Copy for the account screens (Figma ACC-01 / 02 / 03). Arabic first, English second,
// same pattern as SeenStrings; kept with the feature so that file does not grow.
import '../../../../core/theme/seen_format.dart' show SeenFormat;
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../domain/entities/agency_profile.dart';
import '../../domain/entities/service_margin.dart';
import '../../domain/entities/team_member.dart';
import '../bloc/profile_cubits.dart';

extension ProfileStrings on SeenStrings {
  String _t(String ar, String en) => isArabic ? ar : en;

  // ── ACC-01 ──
  String get agencyDetailsTitle => _t('بيانات الوكالة', 'Agency details');
  String get editAction => _t('تعديل', 'Edit');
  String get agencyName => _t('اسم الوكالة', 'Agency name');
  String get licenseNumber => _t('رقم الترخيص', 'License number');
  String get cityLabel => _t('المدينة', 'City');
  String get managerLabel => _t('المسؤول', 'Manager');
  String get documentsTitle => _t('المستندات', 'Documents');
  String verificationChip(AgencyVerification v) => switch (v) {
        AgencyVerification.verified => _t('موثّقة', 'Verified'),
        AgencyVerification.pending => _t('قيد المراجعة', 'Under review'),
        AgencyVerification.rejected => _t('مرفوضة', 'Rejected'),
        AgencyVerification.unverified => _t('غير موثّقة', 'Not verified'),
      };
  String verificationLine(AgencyVerification v, DateTime? at) => switch (v) {
        AgencyVerification.verified => at == null
            ? _t('تم توثيق الوكالة', 'The agency is verified')
            : _t('تم توثيق الوكالة · ${dayMonth(at)} ${year(at.year)}',
                'The agency was verified · ${dayMonth(at)} ${at.year}'),
        AgencyVerification.pending => _t('مستنداتك قيد المراجعة. سنبلغك عند اكتمال التوثيق.',
            'Your documents are under review. We will tell you when verification is done.'),
        AgencyVerification.rejected => _t('تعذّر توثيق الوكالة. تواصل مع الدعم.',
            'The agency could not be verified. Contact support.'),
        AgencyVerification.unverified =>
          _t('الوكالة لم تُوثّق بعد.', 'The agency has not been verified yet.'),
      };
  String documentName(AgencyDocumentKind k) => switch (k) {
        AgencyDocumentKind.commercialRegister => _t('السجل التجاري', 'Commercial register'),
        AgencyDocumentKind.tourismLicense => _t('الترخيص السياحي', 'Tourism license'),
        AgencyDocumentKind.other => _t('مستند', 'Document'),
      };
  String _days(int n) => !isArabic
      ? (n == 1 ? '1 day' : '$n days')
      : switch (n) {
          1 => 'يوم',
          2 => 'يومين',
          >= 3 && <= 10 => '${numeral(n)} أيام',
          _ => '${numeral(n)} يومًا',
        };
  String documentExpiryLine(AgencyDocument d, DateTime today) {
    final left = d.daysLeft(today);
    final at = d.expiresAt;
    if (left == null || at == null) return '';
    if (left < 0) return _t('انتهت صلاحيته', 'Expired');
    if (left == 0) return _t('ينتهي اليوم', 'Expires today');
    if (left <= documentExpiryWarningDays) return _t('ينتهي خلال ${_days(left)}', 'Expires in ${_days(left)}');
    return _t('صالح حتى ${monthYear(at)}', 'Valid until ${monthYear(at)}');
  }
  String get renewAction => _t('تجديد', 'Renew');
  String get viewAction => _t('عرض', 'View');
  String get documentUnavailable => _t('تعذّر فتح المستند.', 'Could not open the document.');
  String get editAgencyInfo => _t('لتعديل بيانات الوكالة تواصل مع جُباري.', 'To change the agency details, contact Jubari.');
  String get renewInfo => _t('لتجديد المستند تواصل مع جُباري. رفع المستندات من التطبيق قريبًا.',
      'To renew the document, contact Jubari. Uploading documents from the app is coming soon.');
  String get contactSupportAction => _t('تواصل مع الدعم', 'Contact support');
  String get loadFailedTitle => _t('تعذّر التحميل', 'Could not load');
  String get retry => _t('إعادة المحاولة', 'Try again');

  // ── ACC-02 ──
  String get marginTitle => _t('هامش الربح', 'Profit margin');
  String get marginBanner => _t('الهامش يُضاف على سعر الخدمة لوكلائك الفرعيين فقط، ولا يظهر لعملائك.',
      'The margin is added to the service price for your sub-agents only, and is not shown to your customers.');
  String marginLocked(String names) => _t('🔒 $names تحدده جُباري (للقراءة فقط)', '🔒 $names is set by Jubari (read only)');
  String get marginViewOnly => _t('عرض فقط: تعديل الهامش لمالك الحساب.', 'View only: the account owner edits margins.');
  String get changeLog => _t('سجل التغييرات', 'Change log');
  String get changeLogEmpty => _t('لا تغييرات بعد.', 'No changes yet.');
  String get saveChanges => _t('حفظ التغييرات', 'Save changes');
  String get marginSaved => _t('تم حفظ الهامش.', 'Margin saved.');
  String get marginSaveFailed => _t('تعذّر حفظ الهامش. حاول مرة أخرى.', 'Could not save the margin. Try again.');
  String get marginRejected => _t('رفض الخادم قيمة الهامش. راجع الأرقام.', 'The server rejected the margin. Check the numbers.');
  String marginFieldLabel(MarginKind k) => k == MarginKind.fixed ? _t('الهامش (USD)', 'Margin (USD)') : _t('الهامش (٪)', 'Margin (%)');
  String get marginInvalid => _t('أدخل رقمًا صحيحًا (٠ أو أكبر).', 'Enter a valid number (0 or more).');
  String get applyAction => _t('تطبيق', 'Apply');
  String get discardTitle => _t('تجاهل التغييرات؟', 'Discard changes?');
  String get discardBody => _t('لم تحفظ تغييرات الهامش.', 'The margin changes are not saved.');
  String get discardAction => _t('تجاهل', 'Discard');
  String get keepEditing => _t('متابعة التعديل', 'Keep editing');

  /// "10 USD" (whole dollars without decimals) or "3%" / "٣٪".
  String marginValue(MarginKind k, int v) {
    if (k == MarginKind.fixed) {
      final whole = v % 100 == 0;
      return SeenFormat.isolate(whole ? '${v ~/ 100} USD' : '${SeenFormat.money(v / 100)} USD');
    }
    final pct = v % 100 == 0 ? numeral(v ~/ 100) : (v / 100).toString();
    return isArabic ? '$pct٪' : '$pct%';
  }

  String marginChangeLine(MarginChange c) {
    final from = c.kind == MarginKind.fixed ? _plain(c.from) : marginValue(c.kind, c.from);
    final to = marginValue(c.kind, c.to);
    final arrow = c.kind == MarginKind.fixed ? SeenFormat.isolate('$from → ${_plainUsd(c.to)}') : '$from → $to';
    return '${c.serviceName}: $arrow · ${dayMonth(c.at)} · ${c.by}';
  }

  String _plain(int cents) => cents % 100 == 0 ? '${cents ~/ 100}' : SeenFormat.money(cents / 100);
  String _plainUsd(int cents) => '${_plain(cents)} USD';

  // ── ACC-03 ──
  String get teamTitle => _t('المستخدمون والصلاحيات', 'Users and permissions');
  String get rolesTitle => _t('الأدوار', 'Roles');
  String roleName(TeamRole r) => switch (r) {
        TeamRole.owner => _t('مالك الحساب', 'Account owner'),
        TeamRole.branchManager => _t('مدير فرع', 'Branch manager'),
        TeamRole.staff => _t('موظف', 'Staff'),
      };
  String roleDescription(TeamRole r) => switch (r) {
        TeamRole.owner => _t('كل الصلاحيات، المحفظة، الفروع', 'Everything: wallet, branches'),
        TeamRole.branchManager =>
          _t('طلبات وموظفو فرعه، دون المحفظة الرئيسية', 'His branch requests and staff, not the main wallet'),
        TeamRole.staff => _t('إنشاء الطلبات ومتابعتها فقط', 'Create and follow requests only'),
      };
  String memberSubtitle(TeamMember m) =>
      '${roleName(m.role)} · ${m.branchName ?? _t('كل الفروع', 'All branches')}';
  String memberStatus(TeamMemberStatus s) => switch (s) {
        TeamMemberStatus.active => _t('نشط', 'Active'),
        TeamMemberStatus.invited => _t('دعوة مُرسلة', 'Invite sent'),
        TeamMemberStatus.disabled => _t('معطّل', 'Disabled'),
      };
  String get inviteUser => _t('دعوة مستخدم', 'Invite a user');
  String get inviteName => _t('الاسم الكامل', 'Full name');
  String get invitePhone => _t('رقم الجوال', 'Mobile number');
  String get inviteRole => _t('الدور', 'Role');
  String get inviteBranch => _t('الفرع', 'Branch');
  String get inviteSend => _t('إرسال الدعوة', 'Send invite');
  String get fieldRequired => _t('هذا الحقل مطلوب.', 'This field is required.');
  String get phoneInvalid => _t('أدخل رقم جوال صحيحًا.', 'Enter a valid mobile number.');
  String teamNotice(TeamNotice n) => switch (n) {
        TeamNotice.invited => _t('أرسلنا الدعوة.', 'Invite sent.'),
        TeamNotice.roleChanged => _t('تم تغيير الدور.', 'Role changed.'),
        TeamNotice.disabled => _t('تم تعطيل المستخدم.', 'User disabled.'),
        TeamNotice.reactivated => _t('تم تفعيل المستخدم.', 'User reactivated.'),
        TeamNotice.inviteResent => _t('أعدنا إرسال الدعوة.', 'Invite sent again.'),
        TeamNotice.inviteCancelled => _t('ألغينا الدعوة.', 'Invite cancelled.'),
        TeamNotice.failed => _t('تعذّر تنفيذ الإجراء. حاول مرة أخرى.', 'Could not do that. Try again.'),
      };
  String get changeRoleAction => _t('تغيير الدور', 'Change role');
  String get disableUserAction => _t('تعطيل المستخدم', 'Disable user');
  String get enableUserAction => _t('تفعيل المستخدم', 'Reactivate user');
  String get resendInviteAction => _t('إعادة إرسال الدعوة', 'Resend invite');
  String get cancelInviteAction => _t('إلغاء الدعوة', 'Cancel invite');
  String disableTitle(String name) => _t('تعطيل $name؟', 'Disable $name?');
  String get disableBody => _t('لن يتمكن من الدخول حتى تعيد تفعيله.', 'They cannot sign in until you reactivate them.');
  String get teamForbidden => _t('إدارة المستخدمين لمالك الحساب ومديري الفروع. اطلب الصلاحية من مالك الحساب.',
      'Users are managed by the account owner and branch managers. Ask the account owner for access.');
}
