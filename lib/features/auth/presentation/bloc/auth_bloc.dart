import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/debug_fallbacks.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/permissions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/auth_session_controller.dart';
import '../../domain/entities/auth_attempt_result.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/usecases/get_persisted_session_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/resend_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginUseCase loginUseCase,
    required VerifyOtpUseCase verifyOtpUseCase,
    required ResendOtpUseCase resendOtpUseCase,
    required LogoutUseCase logoutUseCase,
    required GetPersistedSessionUseCase getPersistedSessionUseCase,
    required AuthSessionController authSessionController,
  })  : _loginUseCase = loginUseCase,
        _verifyOtpUseCase = verifyOtpUseCase,
        _resendOtpUseCase = resendOtpUseCase,
        _logoutUseCase = logoutUseCase,
        _getPersistedSessionUseCase = getPersistedSessionUseCase,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginSubmitted>(_onLoginSubmitted, transformer: droppable());
    on<AuthOtpSubmitted>(_onOtpSubmitted, transformer: droppable());
    on<AuthOtpResendRequested>(_onOtpResendRequested, transformer: droppable());
    on<AuthOtpCancelled>(_onOtpCancelled);
    on<AuthLogoutRequested>(_onLogoutRequested, transformer: droppable());
    on<AuthSessionInvalidated>(_onSessionInvalidated);
    on<AuthSessionExpiredAcknowledged>(_onSessionExpiredAcknowledged, transformer: droppable());
    on<AuthDebugBypassRequested>(_onDebugBypassRequested);

    // Owned here: subscribed in the constructor, cancelled in close().
    _sessionSubscription = authSessionController.events.listen((event) {
      // Only `unauthenticated` (401 — invalid/expired token) ends the
      // session. `forbidden` (403) is a per-action permission denial, not a
      // reason to log a validly-authenticated user out.
      if (event == AuthSessionEvent.unauthenticated) {
        add(const AuthSessionInvalidated());
      }
    });
  }

  final LoginUseCase _loginUseCase;
  final VerifyOtpUseCase _verifyOtpUseCase;
  final ResendOtpUseCase _resendOtpUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetPersistedSessionUseCase _getPersistedSessionUseCase;
  late final StreamSubscription<AuthSessionEvent> _sessionSubscription;

  /// Identifier of the in-flight login, echoed into [AuthOtpRequired] so the
  /// OTP screen can show where the code went. Display only.
  String? _pendingIdentifier;

  /// Convenience accessor for gating UI actions off the current session.
  bool hasPermission(String code) {
    final current = state;
    return current is AuthAuthenticated && current.hasPermission(code);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final session = await _getPersistedSessionUseCase();
    emit(session != null ? AuthAuthenticated(session) : const AuthUnauthenticated());
  }

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    _pendingIdentifier = event.identifier;
    final result = await _loginUseCase(
      identifier: event.identifier,
      password: event.password,
    );
    emit(
      result.match(
        (failure) => _loginFailure(failure),
        (attempt) => switch (attempt) {
          AuthOtpChallenge(:final challengeToken, :final resendCooldownSeconds, :final canResend) =>
            AuthOtpRequired(
              challengeToken: challengeToken,
              resendCooldownSeconds: resendCooldownSeconds,
              identifier: _pendingIdentifier,
              canResend: canResend,
            ),
          AuthSuccess(:final session) => AuthAuthenticated(session),
        },
      ),
    );
  }

  // Codes of the contract (docs/api/mobile-api.md section 3.1) plus the two the
  // repository raises itself.
  static const _invalidCredentialsCode = 'invalid_credentials';
  static const _pendingCode = 'agency_pending';
  static const _suspendedCode = 'agency_suspended';
  static const _tooManyAttemptsCode = 'too_many_attempts';
  static const _enrollmentCode = 'enrollment_link_required';
  static const _challengeInvalidCodes = {'otp_challenge_invalid', 'enrollment_challenge_invalid'};
  static const _emailRequiredCode = 'email_required';

  AuthFailure _loginFailure(Failure failure) {
    int? number(Map<String, Object?> d, String key) {
      final v = d[key];
      return v is num ? v.toInt() : int.tryParse('$v');
    }

    if (failure is ServerFailure) {
      final reason = switch (failure.code) {
        _invalidCredentialsCode => LoginFailureReason.invalidCredentials,
        _pendingCode => LoginFailureReason.pendingApproval,
        _suspendedCode => LoginFailureReason.suspended,
        _tooManyAttemptsCode => LoginFailureReason.locked,
        _enrollmentCode => LoginFailureReason.enrollmentLinkRequired,
        _ => LoginFailureReason.generic,
      };
      // `too_many_attempts` carries the wait in minutes.
      final minutes = number(failure.details, 'minutes');
      return AuthFailure(
        message: failure.message,
        stage: AuthFailureStage.login,
        reason: reason,
        attemptsLeft: number(failure.details, 'attemptsLeft'),
        retryAfterSeconds: minutes != null ? minutes * 60 : number(failure.details, 'retryAfterSeconds'),
        cause: failure,
      );
    }
    if (failure is ValidationFailure && failure.fieldErrors.values.any((codes) => codes.contains(_emailRequiredCode))) {
      return AuthFailure(
        message: failure.message,
        stage: AuthFailureStage.login,
        reason: LoginFailureReason.emailRequired,
        cause: failure,
      );
    }
    return AuthFailure(message: failure.message, stage: AuthFailureStage.login, cause: failure);
  }

  Future<void> _onOtpSubmitted(
    AuthOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final challengeToken = _currentChallengeToken();
    if (challengeToken == null) return; // Stale/out-of-order event.
    final canResend = _currentCanResend();

    emit(const AuthLoading());
    final result = await _verifyOtpUseCase(
      challengeToken: challengeToken,
      code: event.code,
    );
    emit(
      result.match(
        (failure) {
          // The server forgot the challenge (5 minutes): start again at Login.
          if (failure is ServerFailure && _challengeInvalidCodes.contains(failure.code)) {
            return AuthFailure(
              message: failure.message,
              stage: AuthFailureStage.login,
              reason: LoginFailureReason.verificationExpired,
              cause: failure,
            );
          }
          // An account the app cannot continue with (e.g. enrollment) is a login-level failure too.
          if (failure is ServerFailure && failure.code == _enrollmentCode) return _loginFailure(failure);
          return AuthFailure(
            message: failure.message,
            stage: AuthFailureStage.otp,
            challengeToken: challengeToken,
            cause: failure,
            canResend: canResend,
          );
        },
        (session) => AuthAuthenticated(session),
      ),
    );
  }

  Future<void> _onOtpResendRequested(
    AuthOtpResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    final challengeToken = _currentChallengeToken();
    if (challengeToken == null) return;
    final canResend = _currentCanResend();

    final result = await _resendOtpUseCase(challengeToken: challengeToken);
    emit(
      result.match(
        (failure) => AuthFailure(
          message: failure.message,
          stage: AuthFailureStage.otp,
          challengeToken: challengeToken,
          cause: failure,
          canResend: canResend,
        ),
        (challenge) => AuthOtpRequired(
          challengeToken: challenge.challengeToken,
          resendCooldownSeconds: challenge.resendCooldownSeconds,
          identifier: _pendingIdentifier,
          canResend: challenge.canResend,
        ),
      ),
    );
  }

  void _onOtpCancelled(AuthOtpCancelled event, Emitter<AuthState> emit) {
    // Only meaningful while an OTP challenge is pending; a stale event is ignored.
    if (_currentChallengeToken() == null) return;
    _pendingIdentifier = null;
    emit(const AuthUnauthenticated(startOnLogin: true));
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _logoutUseCase();
    emit(const AuthUnauthenticated());
  }

  void _onSessionInvalidated(
    AuthSessionInvalidated event,
    Emitter<AuthState> emit,
  ) {
    final current = state;
    // Several in-flight calls can all come back unauthenticated; the dialog
    // shows once, and a late one must not undo a sign-out screen choice.
    if (current is AuthSessionExpired || current is AuthUnauthenticated) return;
    // Signed in: keep the screen and let the user acknowledge (AUTH-13).
    if (current is AuthAuthenticated) {
      emit(AuthSessionExpired(current.session));
      return;
    }
    emit(const AuthUnauthenticated());
  }

  Future<void> _onSessionExpiredAcknowledged(
    AuthSessionExpiredAcknowledged event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthSessionExpired) return;
    // The token is dead: clear it so a relaunch does not restore it.
    await _logoutUseCase();
    emit(const AuthUnauthenticated(startOnLogin: true));
  }

  /// DEBUG ONLY. Deliberately does not call the repository/use cases, so a
  /// real persisted session is never overwritten by this mock one.
  void _onDebugBypassRequested(
    AuthDebugBypassRequested event,
    Emitter<AuthState> emit,
  ) {
    // Defense in depth: the button that dispatches this is itself compiled
    // out of release builds, but a bypass of real auth must never work in
    // release even if this handler were somehow reached.
    if (!debugFallbacksEnabled) return;
    emit(
      const AuthAuthenticated(
        UserSession(
          userId: 'debug-user',
          userType: UserType.agent,
          positionRaw: 'owner',
          branchId: 'debug-branch',
          permissionCodes: SystemPermissions.all,
        ),
      ),
    );
  }

  bool _currentCanResend() => switch (state) {
        AuthOtpRequired(:final canResend) => canResend,
        AuthFailure(stage: AuthFailureStage.otp, :final canResend) => canResend,
        _ => true,
      };

  /// The OTP challenge token currently in play, from either the OTP-required
  /// state or a failed OTP attempt that should still be retryable.
  String? _currentChallengeToken() => switch (state) {
        AuthOtpRequired(:final challengeToken) => challengeToken,
        AuthFailure(stage: AuthFailureStage.otp, :final challengeToken)
            when challengeToken != null =>
          challengeToken,
        _ => null,
      };

  @override
  Future<void> close() {
    _sessionSubscription.cancel();
    return super.close();
  }
}
