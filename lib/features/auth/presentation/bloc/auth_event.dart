import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched once at app start to restore a persisted session.
final class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

final class AuthLoginSubmitted extends AuthEvent {
  const AuthLoginSubmitted({required this.identifier, required this.password});

  final String identifier;
  final String password;

  @override
  List<Object?> get props => [identifier, password];
}

final class AuthOtpSubmitted extends AuthEvent {
  const AuthOtpSubmitted({required this.code});

  final String code;

  @override
  List<Object?> get props => [code];
}

final class AuthOtpResendRequested extends AuthEvent {
  const AuthOtpResendRequested();
}

/// The user backed out of the OTP step. Drops the pending challenge and
/// returns to Login (no network call: nothing is signed in yet).
final class AuthOtpCancelled extends AuthEvent {
  const AuthOtpCancelled();
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Raised internally when [AuthSessionController] reports the session is no
/// longer valid (a 401 from any request, anywhere in the app). Not meant to
/// be dispatched from the UI.
final class AuthSessionInvalidated extends AuthEvent {
  const AuthSessionInvalidated();
}

/// The user acknowledged the "session expired" dialog: clear the stored
/// session and go to Login.
final class AuthSessionExpiredAcknowledged extends AuthEvent {
  const AuthSessionExpiredAcknowledged();
}

/// DEBUG ONLY — bypasses the real login/OTP flow with a mock, fully
/// permissioned session, so screens can be exercised without a live
/// backend. The bloc no-ops this outside a debug build (see `AuthBloc`);
/// never dispatch it from anything but the debug-gated bypass button.
final class AuthDebugBypassRequested extends AuthEvent {
  const AuthDebugBypassRequested();
}
