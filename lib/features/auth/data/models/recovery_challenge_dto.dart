import '../../domain/entities/password_recovery.dart';

/// Wire shape of the request / resend "reset code" responses.
class RecoveryChallengeDto {
  const RecoveryChallengeDto({
    required this.challengeToken,
    required this.maskedDestination,
    required this.resendCooldownSeconds,
  });

  factory RecoveryChallengeDto.fromJson(Map<String, dynamic> json) => RecoveryChallengeDto(
        challengeToken: json['challengeToken'] as String,
        maskedDestination: json['maskedDestination'] as String? ?? '',
        resendCooldownSeconds: json['resendCooldownSeconds'] as int? ?? 60,
      );

  final String challengeToken;
  final String maskedDestination;
  final int resendCooldownSeconds;

  RecoveryChallenge toEntity() => RecoveryChallenge(
        challengeToken: challengeToken,
        maskedDestination: maskedDestination,
        resendCooldownSeconds: resendCooldownSeconds,
      );
}
