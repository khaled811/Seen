import '../../../../core/constants/enums.dart';
import '../../domain/entities/user_session.dart';

/// Wire shape of the `me` query, reduced to what the session needs. `me` is the
/// source of truth for the person's permissions: it is called after every
/// sign-in and on every launch, never cached.
class MeDto {
  const MeDto({required this.id, required this.agentPosition, required this.permissions, required this.hasAgency});

  factory MeDto.fromJson(Map<String, dynamic> json) => MeDto(
        id: json['id'] as String,
        agentPosition: json['agentPosition'] as String?,
        permissions: {
          for (final code in json['permissions'] as List<dynamic>? ?? const []) code as String,
        },
        hasAgency: json['agent'] is Map,
      );

  final String id;
  final String? agentPosition;
  final Set<String> permissions;

  /// Seen staff have no agency; this app is for agency users only (the server
  /// refuses staff operations to agency tokens anyway).
  final bool hasAgency;

  /// The session this person gets. An unknown position or an empty permission
  /// list yields a session that can do nothing: unknown means no access.
  /// `branchId` is not part of the contract's `User` type (open backend question).
  UserSession toSession() => UserSession(
        userId: id,
        userType: UserType.agent,
        positionRaw: agentPosition,
        branchId: null,
        permissionCodes: permissions,
      );
}
