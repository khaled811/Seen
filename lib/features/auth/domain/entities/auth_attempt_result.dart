import 'package:equatable/equatable.dart';

import 'user_session.dart';

/// Outcome of a login (or OTP verification) attempt against the backend.
///
/// The backend flow bifurcates: some sessions require an OTP challenge
/// before issuing a token, others authenticate directly.
sealed class AuthAttemptResult extends Equatable {
  const AuthAttemptResult();
}

/// The backend requires an OTP code before it will issue a session.
final class AuthOtpChallenge extends AuthAttemptResult {
  const AuthOtpChallenge({
    required this.challengeToken,
    required this.resendCooldownSeconds,
    this.canResend = true,
  });

  /// Opaque token identifying this OTP challenge; must be echoed back on
  /// verify/resend.
  final String challengeToken;

  /// Seconds the UI must wait before the resend action becomes available.
  final int resendCooldownSeconds;

  /// Whether the backend can send the code again. The real API verifies an
  /// authenticator (TOTP) code or a recovery code, so there is nothing to resend.
  final bool canResend;

  @override
  List<Object?> get props => [challengeToken, resendCooldownSeconds, canResend];
}

/// Authentication completed: the backend issued a token and session.
final class AuthSuccess extends AuthAttemptResult {
  const AuthSuccess({required this.accessToken, required this.session});

  final String accessToken;
  final UserSession session;

  @override
  List<Object?> get props => [accessToken, session];
}
