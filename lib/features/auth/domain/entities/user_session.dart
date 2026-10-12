import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// The authenticated user's identity and authorization context.
///
/// Pure Dart — no Flutter, no backend/JSON concerns. [permissionCodes] is a
/// UI-gating cache only; the backend re-validates every permission
/// server-side (see [hasPermission]).
class UserSession extends Equatable {
  const UserSession({
    required this.userId,
    required this.userType,
    required this.positionRaw,
    required this.branchId,
    required this.permissionCodes,
  });

  final String userId;
  final UserType userType;

  /// Raw backend position string. Its meaning depends on [userType] — use
  /// [employeePosition] or [agentPosition] rather than reading this directly.
  final String? positionRaw;

  final String? branchId;
  final Set<String> permissionCodes;

  EmployeePosition? get employeePosition => userType == UserType.employee
      ? EmployeePosition.fromValue(positionRaw)
      : null;

  AgentPosition? get agentPosition =>
      userType == UserType.agent ? AgentPosition.fromValue(positionRaw) : null;

  /// Whether this session's cached role grants [permissionCode].
  ///
  /// UI gating only (hide/disable an action) — never a substitute for
  /// server-side enforcement.
  bool hasPermission(String permissionCode) =>
      permissionCodes.contains(permissionCode);

  @override
  List<Object?> get props => [
        userId,
        userType,
        positionRaw,
        branchId,
        permissionCodes,
      ];
}
