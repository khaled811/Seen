/// Backend permission codes (exact raw strings).
///
/// Use these for UI gating only (hiding/disabling actions). The backend is the
/// source of truth and must enforce every permission server-side.
abstract final class SystemPermissions {
  // Requests
  static const String requestViewOwn = 'request.view.own';
  static const String requestViewBranch = 'request.view.branch';
  static const String requestViewAgency = 'request.view.agency';
  static const String requestViewAll = 'request.view.all';
  static const String requestSubmit = 'request.submit';
  static const String requestCancel = 'request.cancel';
  static const String requestEditAll = 'request.edit.all';
  static const String requestApproveManagement = 'request.approve.management';

  // Pricing & Margins
  static const String pricingView = 'pricing.view';
  static const String pricingSetMargin = 'pricing.set_margin';

  // Staff & Sub-Agents
  static const String staffCreate = 'staff.create';
  static const String userPermissionManage = 'user.permission.manage';
  static const String agentCreateSubAgent = 'agent.create_sub_agent';

  // Wallets & Financials
  static const String walletView = 'wallet.view';
  static const String walletTopupRequest = 'wallet.topup.request';
  static const String walletTopupApprove = 'wallet.topup.approve';
  static const String walletTopupSubAgents = 'wallet.topup.sub_agents';
  static const String walletAdjustDirect = 'wallet.adjust.direct';

  // Support Tickets
  static const String ticketGeneralCreate = 'ticket.general.create';
  static const String ticketGeneralResolve = 'ticket.general.resolve';
  static const String ticketWalletAdjustmentCreate =
      'ticket.wallet_adjustment.create';
  static const String ticketWalletAdjustmentResolve =
      'ticket.wallet_adjustment.resolve';

  // Operations & Reporting
  static const String providerSessionRefresh = 'provider.session.refresh';
  static const String dataExport = 'data.export';
  static const String reportCreate = 'report.create';

  /// Every known code; useful for validating payloads from the API.
  static const Set<String> all = {
    requestViewOwn,
    requestViewBranch,
    requestViewAgency,
    requestViewAll,
    requestSubmit,
    requestCancel,
    requestEditAll,
    requestApproveManagement,
    pricingView,
    pricingSetMargin,
    staffCreate,
    userPermissionManage,
    agentCreateSubAgent,
    walletView,
    walletTopupRequest,
    walletTopupApprove,
    walletTopupSubAgents,
    walletAdjustDirect,
    ticketGeneralCreate,
    ticketGeneralResolve,
    ticketWalletAdjustmentCreate,
    ticketWalletAdjustmentResolve,
    providerSessionRefresh,
    dataExport,
    reportCreate,
  };
}
