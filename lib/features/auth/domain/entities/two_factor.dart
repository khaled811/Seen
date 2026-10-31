import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// What the server says about the signed-in user's two-step verification (`me`).
class TwoFactorStatus extends Equatable {
  const TwoFactorStatus({required this.enabled, required this.enrolled, required this.recoveryCodesLeft});

  /// A device is confirmed and a code is asked at every sign-in.
  final bool enabled;

  /// A device was confirmed (the contract's `twoFactorEnrolled`).
  final bool enrolled;
  final int recoveryCodesLeft;

  /// Turned on: either flag says so, because `otpEnabled` may lag after a confirm
  /// (DECISIONS D-34, backend question).
  bool get isOn => enabled || enrolled;

  @override
  List<Object?> get props => [enabled, enrolled, recoveryCodesLeft];
}

/// The secret of a new authenticator device. Held in memory only, never logged.
class TwoFactorSetup extends Equatable {
  const TwoFactorSetup({required this.secret, required this.provisioningUri});

  final String secret;

  /// The `otpauth://` link the QR code encodes.
  final String provisioningUri;

  /// The secret in groups of four (`JBSW Y3DP`), for typing it by hand.
  String get groupedSecret => RegExp('.{1,4}').allMatches(secret).map((m) => m.group(0)!).join(' ');

  @override
  List<Object?> get props => [secret, provisioningUri];
}

enum TwoFactorIssueKind { wrongCode, rateLimited, notEnrolling, notEnrolled, alreadyEnrolled, offline, forbidden, generic }

class TwoFactorIssue extends Equatable {
  const TwoFactorIssue(this.kind, {this.minutes});

  final TwoFactorIssueKind kind;

  /// Minutes until the next try (`too_many_attempts`).
  final int? minutes;

  /// Codes of the contract (reference, "Error codes").
  static const wrongCodeCode = 'otp_code_invalid';
  static const notEnrollingCode = 'otp_not_enrolling';
  static const notEnrolledCode = 'otp_not_enrolled';
  static const alreadyEnrolledCode = 'otp_already_enrolled';
  static const rateLimitedCode = 'too_many_attempts';

  factory TwoFactorIssue.from(Failure failure) {
    if (failure is NetworkFailure) {
      return const TwoFactorIssue(TwoFactorIssueKind.offline);
    }
    if (failure is ForbiddenFailure) {
      return const TwoFactorIssue(TwoFactorIssueKind.forbidden);
    }
    if (failure is ServerFailure) {
      final raw = failure.details['minutes'];
      final minutes = raw is num ? raw.toInt() : int.tryParse('$raw');
      return switch (failure.code) {
        wrongCodeCode => const TwoFactorIssue(TwoFactorIssueKind.wrongCode),
        notEnrollingCode => const TwoFactorIssue(TwoFactorIssueKind.notEnrolling),
        notEnrolledCode => const TwoFactorIssue(TwoFactorIssueKind.notEnrolled),
        alreadyEnrolledCode => const TwoFactorIssue(TwoFactorIssueKind.alreadyEnrolled),
        rateLimitedCode => TwoFactorIssue(TwoFactorIssueKind.rateLimited, minutes: minutes),
        _ => const TwoFactorIssue(TwoFactorIssueKind.generic),
      };
    }
    return const TwoFactorIssue(TwoFactorIssueKind.generic);
  }

  @override
  List<Object?> get props => [kind, minutes];
}
