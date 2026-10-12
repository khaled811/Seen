/// Strongly-typed mirrors of the Seen Booking backend enums (Django TextChoices).
///
/// Pure Dart — safe to use from the domain layer.
///
/// Every enum carries the exact raw API string in [ApiEnum.value]. Parsing is
/// exact-match (the backend contract is case-sensitive) and never throws: any
/// unrecognised or missing value maps to the enum's `unknown` member.
///
/// `unknown` exists so that a new backend value cannot be silently
/// misinterpreted as a real one (e.g. an unknown [PermissionEffect] becoming
/// `grant`, or an unknown [RequestStatus] rendering as `draft`). Callers must
/// handle it explicitly and must NEVER send `unknown` back to the API.
library;

/// Contract shared by every backend-mapped enum.
abstract interface class ApiEnum {
  String get value;
}

/// Linear lookup is intentional: every enum here has at most ~11 members, so
/// this is cheaper than building and holding a map per enum.
T _parse<T extends ApiEnum>(List<T> values, String? raw, T fallback) {
  if (raw == null) return fallback;
  for (final e in values) {
    if (e.value == raw) return e;
  }
  return fallback;
}

enum UserType implements ApiEnum {
  employee('employee'),
  superadmin('superadmin'),
  agent('agent'),
  unknown('');

  const UserType(this.value);
  @override
  final String value;

  static UserType fromValue(String? value) =>
      _parse(values, value, UserType.unknown);
}

enum EmployeePosition implements ApiEnum {
  manager('manager'),
  branchManager('branch_manager'),
  specialist('specialist'),
  accounts('accounts'),
  customerService('customer_service'),
  unknown('');

  const EmployeePosition(this.value);
  @override
  final String value;

  static EmployeePosition fromValue(String? value) =>
      _parse(values, value, EmployeePosition.unknown);
}

enum AgentPosition implements ApiEnum {
  owner('owner'),
  branchManager('branch_manager'),
  staff('staff'),
  unknown('');

  const AgentPosition(this.value);
  @override
  final String value;

  static AgentPosition fromValue(String? value) =>
      _parse(values, value, AgentPosition.unknown);
}

enum PermissionEffect implements ApiEnum {
  grant('grant'),
  revoke('revoke'),
  unknown('');

  const PermissionEffect(this.value);
  @override
  final String value;

  static PermissionEffect fromValue(String? value) =>
      _parse(values, value, PermissionEffect.unknown);
}

enum AgentStatus implements ApiEnum {
  pending('pending'),
  active('active'),
  suspended('suspended'),
  unknown('');

  const AgentStatus(this.value);
  @override
  final String value;

  static AgentStatus fromValue(String? value) =>
      _parse(values, value, AgentStatus.unknown);
}

/// Raw values are UPPERCASE.
enum AgentTier implements ApiEnum {
  a('A'),
  b('B'),
  c('C'),
  unknown('');

  const AgentTier(this.value);
  @override
  final String value;

  static AgentTier fromValue(String? value) =>
      _parse(values, value, AgentTier.unknown);
}

enum RequestStatus implements ApiEnum {
  draft('draft'),
  submitted('submitted'),
  pendingAgentApproval('pending_agent_approval'),
  pendingManagementApproval('pending_management_approval'),
  underReview('under_review'),
  infoRequired('info_required'),
  processing('processing'),
  completed('completed'),
  rejected('rejected'),
  cancelled('cancelled'),
  unknown('');

  const RequestStatus(this.value);
  @override
  final String value;

  static RequestStatus fromValue(String? value) =>
      _parse(values, value, RequestStatus.unknown);
}

enum TransactionType implements ApiEnum {
  topup('topup'),
  hold('hold'),
  finalDeduction('final_deduction'),
  release('release'),
  refund('refund'),
  settlement('settlement'),
  unknown('');

  const TransactionType(this.value);
  @override
  final String value;

  static TransactionType fromValue(String? value) =>
      _parse(values, value, TransactionType.unknown);
}

enum TransactionStatus implements ApiEnum {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  unknown('');

  const TransactionStatus(this.value);
  @override
  final String value;

  static TransactionStatus fromValue(String? value) =>
      _parse(values, value, TransactionStatus.unknown);
}

enum LedgerSide implements ApiEnum {
  debit('debit'),
  credit('credit'),
  unknown('');

  const LedgerSide(this.value);
  @override
  final String value;

  static LedgerSide fromValue(String? value) =>
      _parse(values, value, LedgerSide.unknown);
}

enum TopUpMethod implements ApiEnum {
  bankTransfer('bank_transfer'),
  cash('cash'),
  exchangeHouse('exchange_house'),
  unknown('');

  const TopUpMethod(this.value);
  @override
  final String value;

  static TopUpMethod fromValue(String? value) =>
      _parse(values, value, TopUpMethod.unknown);
}

enum WalletAdjustmentAction implements ApiEnum {
  credit('credit'),
  debit('debit'),
  unknown('');

  const WalletAdjustmentAction(this.value);
  @override
  final String value;

  static WalletAdjustmentAction fromValue(String? value) =>
      _parse(values, value, WalletAdjustmentAction.unknown);
}

/// Raw values are UPPERCASE (ISO 4217).
enum WalletCurrency implements ApiEnum {
  usd('USD'),
  unknown('');

  const WalletCurrency(this.value);
  @override
  final String value;

  static WalletCurrency fromValue(String? value) =>
      _parse(values, value, WalletCurrency.unknown);
}

enum TicketType implements ApiEnum {
  walletAdjustment('wallet_adjustment'),
  general('general'),
  unknown('');

  const TicketType(this.value);
  @override
  final String value;

  static TicketType fromValue(String? value) =>
      _parse(values, value, TicketType.unknown);
}

enum TicketStatus implements ApiEnum {
  open('open'),
  closed('closed'),
  unknown('');

  const TicketStatus(this.value);
  @override
  final String value;

  static TicketStatus fromValue(String? value) =>
      _parse(values, value, TicketStatus.unknown);
}

enum TicketPriority implements ApiEnum {
  low('low'),
  normal('normal'),
  high('high'),
  urgent('urgent'),
  unknown('');

  const TicketPriority(this.value);
  @override
  final String value;

  static TicketPriority fromValue(String? value) =>
      _parse(values, value, TicketPriority.unknown);
}

enum TicketCategory implements ApiEnum {
  general('general'),
  financialCorrection('financial_correction'),
  unknown('');

  const TicketCategory(this.value);
  @override
  final String value;

  static TicketCategory fromValue(String? value) =>
      _parse(values, value, TicketCategory.unknown);
}

enum FieldType implements ApiEnum {
  text('text'),
  number('number'),
  date('date'),
  phone('phone'),
  email('email'),
  select('select'),
  textarea('textarea'),
  unknown('');

  const FieldType(this.value);
  @override
  final String value;

  static FieldType fromValue(String? value) =>
      _parse(values, value, FieldType.unknown);
}

enum RefundPolicy implements ApiEnum {
  noRefundOnRejection('no_refund_on_rejection'),
  unknown('');

  const RefundPolicy(this.value);
  @override
  final String value;

  static RefundPolicy fromValue(String? value) =>
      _parse(values, value, RefundPolicy.unknown);
}

enum ProviderChannel implements ApiEnum {
  portalManual('portal_manual'),
  portalAutomated('portal_automated'),
  whatsapp('whatsapp'),
  api('api'),
  unknown('');

  const ProviderChannel(this.value);
  @override
  final String value;

  static ProviderChannel fromValue(String? value) =>
      _parse(values, value, ProviderChannel.unknown);
}

enum NotificationEventType implements ApiEnum {
  newRequest('new_request'),
  statusUpdate('status_update'),
  infoRequired('info_required'),
  rejected('rejected'),
  slaBreach('sla_breach'),
  topUp('top_up'),
  newAgentSignup('new_agent_signup'),
  ticketUpdate('ticket_update'),
  unknown('');

  const NotificationEventType(this.value);
  @override
  final String value;

  static NotificationEventType fromValue(String? value) =>
      _parse(values, value, NotificationEventType.unknown);
}

enum AuditEntityType implements ApiEnum {
  request('request'),
  requestTraveler('request_traveler'),
  transaction('transaction'),
  ticket('ticket'),
  agent('agent'),
  user('user'),
  serviceType('service_type'),
  unknown('');

  const AuditEntityType(this.value);
  @override
  final String value;

  static AuditEntityType fromValue(String? value) =>
      _parse(values, value, AuditEntityType.unknown);
}
