import 'package:equatable/equatable.dart';

import '../../domain/entities/user_session.dart';

/// Which screen/step an [AuthFailure] belongs to, so each screen can react
/// only to its own failures via `BlocListener.listenWhen`.
enum AuthFailureStage { login, otp }

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
  });

  final String challengeToken;
  final int resendCooldownSeconds;

  /// The login identifier (phone/email) the code was sent to, so the OTP
  /// screen can say where it went. Display only (masked by the UI); null when
  /// unknown.
  final String? identifier;

  @override
  List<Object?> get props => [challengeToken, resendCooldownSeconds, identifier];
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
  });

  final String message;
  final AuthFailureStage stage;

  /// Preserved on an OTP-stage failure so the OTP screen can retry/resend
  /// without losing the challenge context.
  final String? challengeToken;

  @override
  List<Object?> get props => [message, stage, challengeToken];
}
