import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:graphql_flutter/graphql_flutter.dart';

import '../error/failure.dart';
import 'api_error_codes.dart';

/// Maps a failed GraphQL operation to a domain [Failure].
///
/// Transport problems and GraphQL errors are kept apart:
/// 1. A transport-level [LinkException] (timeout, no network, a non-2xx HTTP
///    answer such as 405/413/429/5xx or a proxy page) becomes a
///    [NetworkFailure] or a [ServerFailure] carrying the status. An HTTP
///    401/403 is *not* a session event: the API answers every application
///    error with HTTP 200, so a 401/403 comes from a proxy or gateway.
/// 2. GraphQL errors (HTTP 200, `errors[].extensions.code`, optional `params`)
///    are keyed by the documented code, never by the message.
Failure mapOperationExceptionToFailure(OperationException exception) {
  final linkException = exception.linkException;
  if (linkException != null) return _mapLinkException(linkException);

  final graphqlErrors = exception.graphqlErrors;
  if (graphqlErrors.isNotEmpty) return _mapGraphQLErrors(graphqlErrors);

  return const ServerFailure('Unknown GraphQL error.');
}

Failure _mapLinkException(LinkException linkException) {
  if (linkException is HttpLinkServerException) {
    final statusCode = linkException.response.statusCode;
    return ServerFailure(
      'Server returned $statusCode.',
      statusCode: statusCode,
      details: {
        if (linkException.response.headers['x-request-id'] != null)
          'requestId': linkException.response.headers['x-request-id'],
      },
    );
  }

  if (linkException is ServerException) {
    // The HTTP client itself failed before any answer came back (dropped
    // connection, DNS failure, or the timeout of the Dio client).
    final original = linkException.originalException;
    final isTimeout = original is TimeoutException;
    if (isTimeout || original is SocketException || original == null) {
      return NetworkFailure(
        isTimeout ? 'Request timed out.' : 'No network connection.',
        isTimeout: isTimeout,
      );
    }
    return ServerFailure('The request failed (${original.runtimeType}).');
  }

  // RequestFormatException / ResponseFormatException / Context*Exception:
  // a client- or server-side bug, not a transient condition. Never include the
  // exception text: it can echo the response body.
  return ServerFailure('Unexpected response (${linkException.runtimeType}).');
}

Failure _mapGraphQLErrors(List<GraphQLError> errors) {
  // A dead session wins over everything else in the same response.
  for (final error in errors) {
    final code = _codeOf(error);
    if (code != null && ApiErrorCodes.sessionEnded.contains(code)) {
      return UnauthorizedFailure(error.message, code);
    }
  }
  final first = errors.first;
  final code = _codeOf(first);
  final params = _paramsOf(first);

  switch (code) {
    case ApiErrorCodes.permissionDenied:
    case 'role_restricted':
      return ForbiddenFailure(first.message, code);
    case ApiErrorCodes.validationFailed:
      final issues = _parseIssues(params['details']);
      final fieldErrors = <String, List<String>>{};
      for (final issue in issues) {
        final field = issue.field;
        if (field != null) (fieldErrors[field] ??= []).add(issue.code);
      }
      return ValidationFailure(first.message, issues: issues, fieldErrors: fieldErrors);
  }

  return ServerFailure(
    errors.map((e) => e.message).join('; '),
    code: code,
    details: {
      ...params,
      if (first.extensions?['requestId'] != null) 'requestId': first.extensions!['requestId'],
    },
  );
}

String? _codeOf(GraphQLError error) {
  final code = error.extensions?['code'];
  return code is String ? code : null;
}

Map<String, Object?> _paramsOf(GraphQLError error) {
  final params = error.extensions?['params'];
  return params is Map ? {for (final e in params.entries) e.key.toString(): e.value} : const {};
}

/// `params.details` is a JSON *string*: `[{"traveler": 0, "field": "x", "code": "..."}]`.
List<ValidationIssue> _parseIssues(Object? details) {
  try {
    final decoded = details is String ? jsonDecode(details) : details;
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map && item['code'] is String)
          ValidationIssue(
            code: item['code'] as String,
            travelerIndex: item['traveler'] is int ? item['traveler'] as int : null,
            field: item['field'] is String ? item['field'] as String : null,
            params: {
              for (final e in item.entries)
                if (!const {'traveler', 'field', 'code'}.contains(e.key)) e.key.toString(): e.value,
            },
          ),
    ];
  } catch (_) {
    return const [];
  }
}
