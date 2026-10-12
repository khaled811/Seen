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
  });

  /// Opaque token identifying this OTP challenge; must be echoed back on
  /// verify/resend.
  final String challengeToken;

  /// Seconds the UI must wait before the resend action becomes available.
  final int resendCooldownSeconds;

  @override
  List<Object?> get props => [challengeToken, resendCooldownSeconds];
}

/// Authentication completed: the backend issued a token and session.
final class AuthSuccess extends AuthAttemptResult {
  const AuthSuccess({required this.accessToken, required this.session});

  final String accessToken;
  final UserSession session;

  @override
  List<Object?> get props => [accessToken, session];
}
