import '../../../../core/constants/enums.dart';
import 'user_session.dart';

/// What a screen or action needs from the signed-in agent's role (Figma ROLE-01).
enum Capability {
  createRequest,
  branchRequests,
  wallet,
  subAgents,
  team,
  margins,
}

/// The one place that says which role may do what, so menus, tabs and screens
/// cannot disagree. Pure Dart.
///
/// This only decides what the app *shows*. The server is the authority and must
/// refuse the same things with 403: hiding a button is not security.
class RolePermissions {
  const RolePermissions(this.position);

  /// Everything (an owner, or a session whose role the server did not name:
  /// the server still answers 403 for what is not allowed).
  static const all = RolePermissions(null);

  factory RolePermissions.fromSession(UserSession session) => RolePermissions(session.agentPosition);

  final AgentPosition? position;

  bool get _full => position == null || position == AgentPosition.owner || position == AgentPosition.unknown;

  bool can(Capability c) {
    if (_full) return true;
    return switch (position!) {
      AgentPosition.branchManager => c == Capability.createRequest || c == Capability.branchRequests || c == Capability.team,
      AgentPosition.staff => c == Capability.createRequest,
      _ => true,
    };
  }

  /// A role with fewer rights than the owner: gets the role-based home.
  bool get isRestricted => Capability.values.any((c) => !can(c));

  /// What [role] may do, for the "differences between roles" table.
  static bool roleCan(AgentPosition role, Capability c) => RolePermissions(role).can(c);
}
