import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// What the user typed on the first registration step (Figma 15). Pure Dart.
class AgencyRegistrationDraft extends Equatable {
  const AgencyRegistrationDraft({
    required this.agencyName,
    required this.managerName,
    required this.phone,
    required this.email,
    required this.city,
    required this.licenseNumber,
  });

  final String agencyName;
  final String managerName;

  /// E.164, e.g. `+967771234567`.
  final String phone;
  final String email;
  final String city;
  final String licenseNumber;

  @override
  List<Object?> get props => [agencyName, managerName, phone, email, city, licenseNumber];
}

/// The consent the user gave on the last step (Figma AUTH-07). Terms and
/// privacy are mandatory; marketing is optional and off by default.
class RegistrationConsent extends Equatable {
  const RegistrationConsent({required this.acceptedTerms, required this.acceptedPrivacy, this.marketing = false});

  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final bool marketing;

  @override
  List<Object?> get props => [acceptedTerms, acceptedPrivacy, marketing];
}

/// A pending phone verification for a registration: where the code went and
/// when it can be asked for again.
class RegistrationChallenge extends Equatable {
  const RegistrationChallenge({
    required this.challengeToken,
    required this.maskedPhone,
    required this.resendCooldownSeconds,
  });

  final String challengeToken;
  final String maskedPhone;
  final int resendCooldownSeconds;

  @override
  List<Object?> get props => [challengeToken, maskedPhone, resendCooldownSeconds];
}

enum RegistrationIssueKind {
  /// The phone already belongs to another account (Figma AUTH-06 banner).
  phoneTaken,

  /// The licence number belongs to another agency (Figma AUTH-08).
  licenseTaken,

  /// The e-mail belongs to another account (Figma AUTH-08).
  emailTaken,
  rateLimited,
  offline,
  wrongCode,
  expiredCode,
  attemptsExhausted,
  weakPassword,
  generic,
}

/// A [Failure] in the vocabulary of the registration screens.
class RegistrationIssue extends Equatable {
  const RegistrationIssue(this.kind, {this.seconds, this.attemptsLeft, this.minutes});

  final RegistrationIssueKind kind;
  final int? seconds;
  final int? attemptsLeft;
  final int? minutes;

  /// Backend error codes (GraphQL `extensions.code`) this mapping expects.
  /// TODO(backend-contract): confirm the names; see docs/BACKEND_MIGRATION_GAPS.md.
  static const phoneTakenCode = 'PHONE_ALREADY_REGISTERED';
  static const licenseTakenCode = 'LICENSE_ALREADY_REGISTERED';
  static const emailTakenCode = 'EMAIL_ALREADY_REGISTERED';
  static const rateLimitedCode = 'RATE_LIMITED';
  static const wrongCodeCode = 'OTP_INVALID';
  static const expiredCodeCode = 'OTP_EXPIRED';
  static const exhaustedCode = 'OTP_ATTEMPTS_EXHAUSTED';
  static const weakPasswordCode = 'PASSWORD_WEAK';

  factory RegistrationIssue.from(Failure failure) {
    if (failure is NetworkFailure) return const RegistrationIssue(RegistrationIssueKind.offline);
    if (failure is ServerFailure) {
      int? number(String key) {
        final v = failure.details[key];
        return v is num ? v.toInt() : int.tryParse('$v');
      }

      return switch (failure.code) {
        phoneTakenCode => const RegistrationIssue(RegistrationIssueKind.phoneTaken),
        licenseTakenCode => const RegistrationIssue(RegistrationIssueKind.licenseTaken),
        emailTakenCode => const RegistrationIssue(RegistrationIssueKind.emailTaken),
        rateLimitedCode => RegistrationIssue(RegistrationIssueKind.rateLimited, seconds: number('retryAfterSeconds')),
        wrongCodeCode => RegistrationIssue(RegistrationIssueKind.wrongCode, attemptsLeft: number('attemptsLeft')),
        expiredCodeCode => const RegistrationIssue(RegistrationIssueKind.expiredCode),
        exhaustedCode => RegistrationIssue(RegistrationIssueKind.attemptsExhausted, minutes: number('lockoutMinutes')),
        weakPasswordCode => const RegistrationIssue(RegistrationIssueKind.weakPassword),
        _ => const RegistrationIssue(RegistrationIssueKind.generic),
      };
    }
    return const RegistrationIssue(RegistrationIssueKind.generic);
  }

  /// A problem with something typed on the form step: the flow goes back there
  /// and marks the field instead of showing a banner.
  bool get isFormFieldConflict =>
      kind == RegistrationIssueKind.licenseTaken || kind == RegistrationIssueKind.emailTaken;

  @override
  List<Object?> get props => [kind, seconds, attemptsLeft, minutes];
}
