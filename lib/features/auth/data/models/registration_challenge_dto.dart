import '../../domain/entities/agency_registration.dart';

/// Wire shape of the start / resend phone-code responses.
class RegistrationChallengeDto {
  const RegistrationChallengeDto({
    required this.challengeToken,
    required this.maskedPhone,
    required this.resendCooldownSeconds,
  });

  factory RegistrationChallengeDto.fromJson(Map<String, dynamic> json) => RegistrationChallengeDto(
        challengeToken: json['challengeToken'] as String,
        maskedPhone: json['maskedPhone'] as String? ?? '',
        resendCooldownSeconds: json['resendCooldownSeconds'] as int? ?? 60,
      );

  final String challengeToken;
  final String maskedPhone;
  final int resendCooldownSeconds;

  RegistrationChallenge toEntity() => RegistrationChallenge(
        challengeToken: challengeToken,
        maskedPhone: maskedPhone,
        resendCooldownSeconds: resendCooldownSeconds,
      );
}
