import '../../../../core/constants/enums.dart';
import '../../domain/entities/user_session.dart';

/// Wire/local-cache shape of a user's identity and permissions.
///
/// Used both ways: [AuthUserDto.fromJson] parses the backend response;
/// [toJson] serializes for the local secure-storage cache; [toEntity] /
/// [AuthUserDto.fromEntity] are the explicit mappers to and from the domain
/// entity, per our Clean Architecture data-layer contract.
class AuthUserDto {
  const AuthUserDto({
    required this.id,
    required this.userType,
    required this.position,
    required this.branchId,
    required this.permissionCodes,
  });

  factory AuthUserDto.fromJson(Map<String, dynamic> json) => AuthUserDto(
        id: json['id'] as String,
        userType: json['userType'] as String?,
        position: json['position'] as String?,
        branchId: json['branchId'] as String?,
        permissionCodes: (json['permissionCodes'] as List<dynamic>? ?? const [])
            .map((code) => code as String)
            .toSet(),
      );

  factory AuthUserDto.fromEntity(UserSession session) => AuthUserDto(
        id: session.userId,
        userType: session.userType.value,
        position: session.positionRaw,
        branchId: session.branchId,
        permissionCodes: session.permissionCodes,
      );

  final String id;
  final String? userType;
  final String? position;
  final String? branchId;
  final Set<String> permissionCodes;

  UserSession toEntity() => UserSession(
        userId: id,
        userType: UserType.fromValue(userType),
        positionRaw: position,
        branchId: branchId,
        permissionCodes: permissionCodes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userType': userType,
        'position': position,
        'branchId': branchId,
        'permissionCodes': permissionCodes.toList(),
      };
}
