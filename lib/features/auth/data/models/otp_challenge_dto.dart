import '../../domain/entities/auth_attempt_result.dart';

/// Wire shape of a `resendOtp` response.
class OtpChallengeDto {
  const OtpChallengeDto({
    required this.challengeToken,
    required this.resendCooldownSeconds,
  });

  factory OtpChallengeDto.fromJson(Map<String, dynamic> json) =>
      OtpChallengeDto(
        challengeToken: json['challengeToken'] as String,
        resendCooldownSeconds: json['resendCooldownSeconds'] as int? ?? 60,
      );

  final String challengeToken;
  final int resendCooldownSeconds;

  AuthOtpChallenge toEntity() => AuthOtpChallenge(
        challengeToken: challengeToken,
        resendCooldownSeconds: resendCooldownSeconds,
      );
}
