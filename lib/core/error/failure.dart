import 'package:equatable/equatable.dart';

/// Domain-facing error returned on the `Left` side of `Either<Failure, T>`.
///
/// Data sources return these directly (`Left`); the presentation layer only ever
/// sees [Failure]s.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// Developer-oriented description. Map to localized user copy in the UI.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Backend returned an error response (5xx, GraphQL errors, malformed payload).
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode, this.code, this.details = const {}});

  final int? statusCode;

  /// Backend-specific error code (e.g. GraphQL `extensions.code`).
  final String? code;

  /// Structured extras that go with [code] (e.g. `retryAfterSeconds`,
  /// `attemptsLeft`), usually from GraphQL `extensions`.
  final Map<String, Object?> details;

  @override
  List<Object?> get props => [message, statusCode, code, details];
}

/// No connectivity or the request timed out.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {this.isTimeout = false});

  final bool isTimeout;

  @override
  List<Object?> get props => [message, isTimeout];
}

/// The session is missing or over (`not_authenticated`, `session_expired`,
/// `no_refresh_session`). Should trigger re-authentication.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Unauthorized', this.code]);

  /// The backend `extensions.code`, when there was one.
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

/// Authenticated but not allowed (`permission_denied`, `role_restricted`).
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message = 'Forbidden', this.code]);

  /// The backend `extensions.code`, when there was one.
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

/// Local persistence (secure storage / cache) read or write failed.
final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// One backend validation problem (`validation_failed`, `params.details`).
final class ValidationIssue extends Equatable {
  const ValidationIssue({required this.code, this.travelerIndex, this.field, this.params = const {}});

  /// The rule that failed (a backend code, localized by the UI).
  final String code;

  /// Which traveler of the request, when the problem is per traveler.
  final int? travelerIndex;

  /// The `fieldKey` of the form field, when the problem is on one field.
  final String? field;

  /// Extra values for the message (limits, dates, ...).
  final Map<String, Object?> params;

  @override
  List<Object?> get props => [code, travelerIndex, field, params];
}

/// Input rejected, client-side or by backend validation.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}, this.issues = const []});

  /// Field name -> error messages (or codes), as returned by the backend.
  final Map<String, List<String>> fieldErrors;

  /// The exact backend problems, in order, when the backend sent them.
  final List<ValidationIssue> issues;

  @override
  List<Object?> get props => [message, fieldErrors, issues];
}

extension FailureReference on Failure {
  /// A short diagnostic for support, shown on error screens: the HTTP status
  /// (or the backend code) and the first four characters of the backend request
  /// id, e.g. `502 · a91f`. Null when there is nothing useful to quote.
  String? get reference {
    final self = this;
    if (self is! ServerFailure) return null;
    final what = self.statusCode?.toString() ?? self.code;
    final id = self.details['requestId'];
    final short = id is String && id.isNotEmpty ? id.substring(0, id.length < 4 ? id.length : 4) : null;
    if (what == null && short == null) return null;
    return [if (what != null) what, if (short != null) short].join(' · ');
  }
}
