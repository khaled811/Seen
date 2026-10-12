import '../../domain/entities/auth_attempt_result.dart';
import 'auth_user_dto.dart';

/// Wire shape of a `login`/`verifyOtp` response.
///
/// TODO(backend-contract): field names (`requiresOtp`, `challengeToken`,
/// `resendCooldownSeconds`, `accessToken`, `user`) are placeholders pending
/// the real Seen Booking GraphQL schema — update here and in
/// `auth_remote_data_source.dart` once confirmed. Kept in one place so a
/// contract change is a small, localized edit.
class AuthPayloadDto {
  const AuthPayloadDto({
    required this.requiresOtp,
    this.challengeToken,
    this.resendCooldownSeconds,
    this.accessToken,
    this.user,
  });

  factory AuthPayloadDto.fromJson(Map<String, dynamic> json) => AuthPayloadDto(
        requiresOtp: json['requiresOtp'] as bool? ?? false,
        challengeToken: json['challengeToken'] as String?,
        resendCooldownSeconds: json['resendCooldownSeconds'] as int?,
        accessToken: json['accessToken'] as String?,
        user: json['user'] == null
            ? null
            : AuthUserDto.fromJson(json['user'] as Map<String, dynamic>),
      );

  final bool requiresOtp;
  final String? challengeToken;
  final int? resendCooldownSeconds;
  final String? accessToken;
  final AuthUserDto? user;

  /// Maps to the domain result.
  ///
  /// Throws [FormatException] if the backend claims a branch (OTP-required
  /// or authenticated) without the fields that branch requires — a backend
  /// contract violation, surfaced rather than silently swallowed (per our
  /// error-handling rules), never something the UI is expected to recover
  /// from gracefully.
  AuthAttemptResult toDomain() {
    if (requiresOtp) {
      final token = challengeToken;
      if (token == null) {
        throw const FormatException(
          'Auth payload: requiresOtp=true but challengeToken is missing.',
        );
      }
      return AuthOtpChallenge(
        challengeToken: token,
        resendCooldownSeconds: resendCooldownSeconds ?? 60,
      );
    }

    final token = accessToken;
    final userDto = user;
    if (token == null || userDto == null) {
      throw const FormatException(
        'Auth payload: requiresOtp=false but accessToken/user is missing.',
      );
    }
    return AuthSuccess(accessToken: token, session: userDto.toEntity());
  }
}
