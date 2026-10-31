import '../../../../core/constants/enums.dart';
import '../../../../core/constants/permissions.dart';
import 'user_session.dart';

/// What a screen or action needs from the signed-in agent's role (Figma ROLE-01).
enum Capability {
  createRequest,
  branchRequests,
  wallet,
  subAgents,
  team,
  margins,

  /// The branch tree and moving people between branches (owner only).
  branches,

  /// Building, running and exporting reports (`report.create`).
  reports,
}

/// The one place that says which role may do what, so menus, tabs and screens
/// cannot disagree. Pure Dart.
///
/// A signed-in person's abilities are the `permissions` the server listed for them
/// (`me.permissions`), mapped to capabilities below. That list is the role's defaults
/// plus the individual grants and revocations the owner made, so a revoked permission
/// hides its control even for an owner. A role named without a session (the "differences
/// between roles" table, tests) uses the role's default list.
///
/// This only decides what the app *shows*. The server is the authority and must
/// refuse the same things with 403: hiding a button is not security.
class RolePermissions {
  /// The default abilities of [position]; null = no session in scope (tests,
  /// pre-sign-in), which allows everything. An unknown position has none.
  const RolePermissions(this.position) : _granted = null;

  /// The abilities the server granted this signed-in person.
  const RolePermissions.fromCodes(Set<String> codes)
      : position = null,
        _granted = codes;

  /// Everything: no session in scope. The server still answers 403 for what is not allowed.
  static const all = RolePermissions(null);

  /// Nothing: a signed-in session with no recognised permission. Unknown permissions fail closed.
  static const none = RolePermissions.fromCodes({});

  /// The session's own permission list; an empty or missing list grants nothing.
  factory RolePermissions.fromSession(UserSession session) => RolePermissions.fromCodes(session.permissionCodes);

  final AgentPosition? position;
  final Set<String>? _granted;

  Set<String> get _codes => _granted ?? (position == null ? SystemPermissions.all : (defaultCodes[position] ?? const {}));

  /// The default permissions of each agency role (backend answer 2026-10-21, from the
  /// role migrations): an Owner of a Main Agent or a Sub-Agent alike, a Branch Manager, Staff.
  static const Map<AgentPosition, Set<String>> defaultCodes = {
    AgentPosition.owner: {
      SystemPermissions.agentCreateSubAgent,
      SystemPermissions.dataExport,
      SystemPermissions.pricingSetMargin,
      SystemPermissions.pricingView,
      SystemPermissions.reportCreate,
      SystemPermissions.requestCancel,
      SystemPermissions.requestSubmit,
      SystemPermissions.requestViewAgency,
      SystemPermissions.staffCreate,
      SystemPermissions.ticketGeneralCreate,
      SystemPermissions.userPermissionManage,
      SystemPermissions.walletTopupRequest,
      SystemPermissions.walletTopupSubAgents,
    },
    AgentPosition.branchManager: {
      SystemPermissions.requestCancel,
      SystemPermissions.requestSubmit,
      SystemPermissions.requestViewBranch,
      SystemPermissions.staffCreate,
      SystemPermissions.ticketGeneralCreate,
    },
    AgentPosition.staff: {
      SystemPermissions.requestCancel,
      SystemPermissions.requestSubmit,
      SystemPermissions.requestViewOwn,
      SystemPermissions.ticketGeneralCreate,
    },
  };

  bool can(Capability c) => switch (c) {
        Capability.createRequest => _codes.contains(SystemPermissions.requestSubmit),
        // Looking at one branch's requests: an agency-wide viewer may pick a branch, a branch viewer is held to theirs.
        Capability.branchRequests => _codes.contains(SystemPermissions.requestViewBranch) || _codes.contains(SystemPermissions.requestViewAgency),
        // The agency wallet is read with `pricing.view` (and is refused to a user limited to one branch).
        Capability.wallet => _codes.contains(SystemPermissions.pricingView),
        Capability.subAgents => _codes.contains(SystemPermissions.agentCreateSubAgent),
        Capability.team => _codes.contains(SystemPermissions.staffCreate),
        Capability.margins => _codes.contains(SystemPermissions.pricingSetMargin),
        // Branches belong to the whole agency: creating one needs `staff.create`, and only an
        // agency-wide viewer sees the whole tree.
        Capability.branches => _codes.contains(SystemPermissions.staffCreate) && _codes.contains(SystemPermissions.requestViewAgency),
        Capability.reports => _codes.contains(SystemPermissions.reportCreate),
      };

  /// A role with fewer rights than the owner: gets the role-based home.
  bool get isRestricted => Capability.values.any((c) => !can(c));

  /// What [role] may do by default, for the "differences between roles" table.
  static bool roleCan(AgentPosition role, Capability c) => RolePermissions(role).can(c);
}
