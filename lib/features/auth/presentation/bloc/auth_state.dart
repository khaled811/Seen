import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/user_session.dart';

/// Which screen/step an [AuthFailure] belongs to, so each screen can react
/// only to its own failures via `BlocListener.listenWhen`.
enum AuthFailureStage { login, otp }

/// Why a login failed, when the server says (Figma AUTH-11).
enum LoginFailureReason {
  /// Anything the screen has no special copy for (shown as a message).
  generic,
  invalidCredentials,

  /// The agency is still being reviewed.
  pendingApproval,
  suspended,

  /// Too many wrong attempts: locked for a while.
  locked,

  /// The API signs in with an e-mail address only (a phone number was typed).
  emailRequired,

  /// Two-step verification must be set up with the e-mailed link, on the web.
  enrollmentLinkRequired,

  /// The second step timed out (the server forgot the challenge): sign in again.
  verificationExpired,
}

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Not yet determined whether a session exists. Shown briefly at app start.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A login/OTP-verification/resend request is in flight.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthOtpRequired extends AuthState {
  const AuthOtpRequired({
    required this.challengeToken,
    required this.resendCooldownSeconds,
    this.identifier,
    this.canResend = true,
  });

  final String challengeToken;
  final int resendCooldownSeconds;

  /// False when the code comes from an authenticator app (nothing to resend).
  final bool canResend;

  /// The login identifier (phone/email) the code was sent to, so the OTP
  /// screen can say where it went. Display only (masked by the UI); null when
  /// unknown.
  final String? identifier;

  @override
  List<Object?> get props => [challengeToken, resendCooldownSeconds, identifier, canResend];
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);

  final UserSession session;

  bool hasPermission(String code) => session.hasPermission(code);

  @override
  List<Object?> get props => [session];
}

/// A request came back 401 while signed in (Figma AUTH-13). The session is
/// already dead, but the app keeps the current screen under a blocking dialog
/// until the user acknowledges it; only then is the stored session cleared and
/// Login shown.
final class AuthSessionExpired extends AuthState {
  const AuthSessionExpired(this.session);

  final UserSession session;

  @override
  List<Object?> get props => [session];
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.startOnLogin = false});

  /// Open the entry flow on Login instead of Welcome (e.g. after backing out
  /// of the OTP step).
  final bool startOnLogin;

  @override
  List<Object?> get props => [startOnLogin];
}

final class AuthFailure extends AuthState {
  const AuthFailure({
    required this.message,
    required this.stage,
    this.challengeToken,
    this.reason = LoginFailureReason.generic,
    this.attemptsLeft,
    this.retryAfterSeconds,
    this.cause,
    this.canResend = true,
  });

  final String message;
  final AuthFailureStage stage;

  /// Preserved on an OTP-stage failure so the OTP screen can retry/resend
  /// without losing the challenge context.
  final String? challengeToken;

  final LoginFailureReason reason;

  /// [LoginFailureReason.invalidCredentials]: attempts before the lock.
  final int? attemptsLeft;

  /// [LoginFailureReason.locked]: how long until the next try is allowed.
  final int? retryAfterSeconds;

  /// The underlying failure; the UI turns it into localized text (the
  /// server's message is never shown).
  final Failure? cause;

  /// Carried through an OTP-stage failure so the screen keeps its resend row
  /// hidden when the code comes from an authenticator app.
  final bool canResend;

  @override
  List<Object?> get props => [message, stage, challengeToken, reason, attemptsLeft, retryAfterSeconds, cause, canResend];
}
