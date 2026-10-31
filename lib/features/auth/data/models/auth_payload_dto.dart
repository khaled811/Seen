/// Wire shape of `AuthResult` (`login`, `verifyOtp`). Exactly one outcome comes
/// back: a token (signed in), `otpRequired` + `challengeId` (second step), or an
/// enrollment flag (the person must set up two-step verification on the web).
///
/// `refreshToken` is always null on this API and is never requested.
class AuthPayloadDto {
  const AuthPayloadDto({
    this.accessToken,
    this.otpRequired = false,
    this.challengeId,
    this.enrollmentRequired = false,
    this.enrollmentCodeRequired = false,
  });

  factory AuthPayloadDto.fromJson(Map<String, dynamic> json) => AuthPayloadDto(
        accessToken: json['accessToken'] as String?,
        otpRequired: json['otpRequired'] as bool? ?? false,
        challengeId: json['challengeId'] as String?,
        enrollmentRequired: json['enrollmentRequired'] as bool? ?? false,
        enrollmentCodeRequired: json['enrollmentCodeRequired'] as bool? ?? false,
      );

  final String? accessToken;
  final bool otpRequired;
  final String? challengeId;
  final bool enrollmentRequired;
  final bool enrollmentCodeRequired;

  bool get needsEnrollment => enrollmentRequired || enrollmentCodeRequired;
}
