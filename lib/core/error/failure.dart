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
  const ServerFailure(super.message, {this.statusCode, this.code});

  final int? statusCode;

  /// Backend-specific error code (e.g. GraphQL `extensions.code`).
  final String? code;

  @override
  List<Object?> get props => [message, statusCode, code];
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
