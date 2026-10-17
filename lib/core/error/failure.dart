import 'package:equatable/equatable.dart';

/// Domain-facing error returned on the `Left` side of `Either<Failure, T>`.
///
/// Repositories map [AppException]s (see `exceptions.dart`) to these; the
/// presentation layer only ever sees [Failure]s.
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

/// 401 — session missing/expired. Should trigger re-authentication.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Unauthorized']);
}

/// 403 — authenticated but lacks the required permission.
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message = 'Forbidden']);
}

/// Local persistence (secure storage / cache) read or write failed.
final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Input rejected, client-side or by backend validation.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});

  /// Field name -> error messages, as returned by the backend.
  final Map<String, List<String>> fieldErrors;

  @override
  List<Object?> get props => [message, fieldErrors];
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
