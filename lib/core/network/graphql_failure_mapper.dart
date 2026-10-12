import 'dart:async';
import 'dart:io';

import 'package:graphql_flutter/graphql_flutter.dart';

import '../error/failure.dart';

/// Maps a failed GraphQL operation to a domain [Failure].
///
/// Check order:
/// 1. Transport-level [LinkException] — a non-2xx HTTP response surfaced as
///    [HttpLinkServerException] (checked for 401/403 first), or a lower-level
///    failure (socket/timeout/DNS) surfaced as a plain [ServerException] with
///    no response attached.
/// 2. GraphQL errors returned alongside a 200 response, keyed off each
///    error's `extensions.code` — the common `UNAUTHENTICATED`/`FORBIDDEN`
///    GraphQL convention — for backends that signal auth failures this way
///    instead of (or in addition to) an HTTP status.
/// 3. A generic [ServerFailure] built from the raw error messages.
Failure mapOperationExceptionToFailure(OperationException exception) {
  final linkException = exception.linkException;
  if (linkException != null) {
    final failure = _mapLinkException(linkException);
    if (failure != null) return failure;
  }

  final graphqlErrors = exception.graphqlErrors;
  if (graphqlErrors.isNotEmpty) {
    final authFailure = _mapGraphQLAuthError(graphqlErrors);
    if (authFailure != null) return authFailure;

    return ServerFailure(
      graphqlErrors.map((e) => e.message).join('; '),
      code: graphqlErrors.first.extensions?['code'] as String?,
    );
  }

  return const ServerFailure('Unknown GraphQL error.');
}

Failure? _mapLinkException(LinkException linkException) {
  if (linkException is HttpLinkServerException) {
    final statusCode = linkException.response.statusCode;
    return switch (statusCode) {
      401 => const UnauthorizedFailure(),
      403 => const ForbiddenFailure(),
      _ => ServerFailure('Server returned $statusCode.', statusCode: statusCode),
    };
  }

  if (linkException is ServerException) {
    // Thrown when the HTTP client itself failed before any response came
    // back (dropped connection, DNS failure, or the timeout raised by our
    // http.Client wrapper) — never a case with a real status code.
    final original = linkException.originalException;
    final isTimeout = original is TimeoutException;
    if (isTimeout || original is SocketException || original == null) {
      return NetworkFailure(
        isTimeout ? 'Request timed out.' : 'No network connection.',
        isTimeout: isTimeout,
      );
    }
    return ServerFailure(linkException.toString());
  }

  // RequestFormatException / ResponseFormatException / Context*Exception:
  // all indicate a client- or server-side bug, not a transient condition.
  return ServerFailure(linkException.toString());
}

/// Returns null when no error carries a recognised auth code, so the caller
/// falls back to a generic [ServerFailure].
Failure? _mapGraphQLAuthError(List<GraphQLError> errors) {
  for (final error in errors) {
    switch (error.extensions?['code']) {
      case 'UNAUTHENTICATED':
        return const UnauthorizedFailure();
      case 'FORBIDDEN':
        return const ForbiddenFailure();
    }
  }
  return null;
}
