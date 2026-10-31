// Copy for the role-based views (Figma ROLE-01) and the settings screen (ACC-04).
import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../auth/domain/entities/role_permissions.dart';

extension RoleStrings on SeenStrings {
  String _t(String ar, String en) => isArabic ? ar : en;

  String roleOf(AgentPosition p) => switch (p) {
        AgentPosition.owner => _t('مالك الحساب', 'Account owner'),
        AgentPosition.branchManager => _t('مدير فرع', 'Branch manager'),
        AgentPosition.staff => _t('موظف', 'Staff'),
        AgentPosition.unknown => '',
      };

  /// Short column heads of the differences table.
  String roleShort(AgentPosition p) => switch (p) {
        AgentPosition.owner => _t('مالك', 'Owner'),
        AgentPosition.branchManager => _t('مدير فرع', 'Manager'),
        AgentPosition.staff => _t('موظف', 'Staff'),
        AgentPosition.unknown => '',
      };

  String roleHomeTitle(AgentPosition p) => '${nav[0]} · ${roleOf(p)}';
  String get walletOwnerOnly => _t('المحفظة متاحة لمالك الحساب فقط', 'The wallet is for the account owner only');
  String get roleDifferences => _t('الفرق بين الأدوار', 'What each role can do');
  String get roleTableYes => _t('مسموح', 'Allowed');
  String get roleTableNo => _t('غير مسموح', 'Not allowed');
  String capabilityLabel(Capability c) => switch (c) {
        Capability.createRequest => _t('إنشاء طلب', 'Create a request'),
        Capability.branchRequests => _t('طلبات الفرع كله', 'The whole branch\'s requests'),
        Capability.wallet => _t('المحفظة والشحن', 'Wallet and top-up'),
        Capability.subAgents => _t('الوكلاء الفرعيون', 'Sub-agents'),
        Capability.team => _t('المستخدمون والفروع', 'Users and branches'),
        Capability.margins => _t('هامش الربح', 'Profit margin'),
        Capability.branches => _t('إدارة الفروع', 'Branch management'),
        Capability.reports => _t('التقارير', 'Reports'),
      };
  String get subAgentsOwnerOnly =>
      _t('الوكلاء الفرعيون متاحون لمالك الحساب فقط. اطلب الصلاحية من مالك الحساب.',
          'Sub-agents are for the account owner only. Ask the account owner for access.');

  // ACC-04
  String get settingsTitle => _t('الإعدادات', 'Settings');
  String get languageRow => _t('اللغة', 'Language');
  String get themeRow => _t('المظهر', 'Appearance');
  String get notificationsRow => _t('الإشعارات', 'Notifications');
  String get branchesRow => _t('الفروع', 'Branches');
  String get changePasswordRow => _t('تغيير كلمة المرور', 'Change password');
  String get changePhoneRow => _t('تغيير رقم الجوال', 'Change mobile number');
  String get biometricRow => _t('الدخول بالبصمة', 'Sign in with fingerprint');
  String get biometricUnavailable => _t('غير متاح بعد', 'Not available yet');
  String get hideBalanceRow => _t('إخفاء الرصيد افتراضيًا', 'Hide the balance by default');
  String get aboutRow => _t('حول التطبيق', 'About the app');
  String versionLine(String v) => _t('الإصدار $v', 'Version $v');
  String themeValue(bool? light) => switch (light) {
        true => _t('فاتح', 'Light'),
        false => _t('داكن', 'Dark'),
        null => _t('تلقائي', 'Automatic'),
      };
  String languageName(String code) => code == 'en' ? 'English' : 'العربية';
}
