import '../../../../core/error/password_rule.dart';
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

enum RegistrationIssueKind {
  /// The owner's e-mail belongs to another account (Figma AUTH-08).
  emailTaken,
  rateLimited,
  offline,
  weakPassword,
  generic,
}

/// A [Failure] in the vocabulary of the registration screens.
class RegistrationIssue extends Equatable {
  const RegistrationIssue(this.kind, {this.seconds, this.attemptsLeft, this.minutes, this.passwordRule});

  final RegistrationIssueKind kind;
  final int? seconds;
  final int? attemptsLeft;
  final int? minutes;

  /// The password rule the server named (`weakPassword` only).
  final String? passwordRule;

  /// Error codes of the contract for `registerMainAgent`.
  static const emailTakenCode = 'owner_email_taken';
  static const rateLimitedCode = 'too_many_attempts';
  static const weakPasswordCode = 'password_weak';

  factory RegistrationIssue.from(Failure failure) {
    if (failure is NetworkFailure) return const RegistrationIssue(RegistrationIssueKind.offline);
    if (failure is ServerFailure) {
      int? number(String key) {
        final v = failure.details[key];
        return v is num ? v.toInt() : int.tryParse('$v');
      }

      return switch (failure.code) {
        emailTakenCode => const RegistrationIssue(RegistrationIssueKind.emailTaken),
        rateLimitedCode => RegistrationIssue(RegistrationIssueKind.rateLimited, minutes: number('minutes')),
        weakPasswordCode => RegistrationIssue(RegistrationIssueKind.weakPassword, passwordRule: passwordRuleOf(failure)),
        _ => const RegistrationIssue(RegistrationIssueKind.generic),
      };
    }
    return const RegistrationIssue(RegistrationIssueKind.generic);
  }

  /// A problem with something typed on the form step: the flow goes back there
  /// and marks the field instead of showing a banner.
  bool get isFormFieldConflict => kind == RegistrationIssueKind.emailTaken;

  @override
  List<Object?> get props => [kind, seconds, attemptsLeft, minutes, passwordRule];
}
