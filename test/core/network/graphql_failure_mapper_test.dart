import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/network/graphql_failure_mapper.dart';

OperationException _gql(String code, {String message = 'm', Map<String, Object?>? params}) => OperationException(
      graphqlErrors: [
        GraphQLError(message: message, extensions: {'code': code, if (params != null) 'params': params}),
      ],
    );

void main() {
  group('GraphQL errors (HTTP 200)', () {
    test('a dead session, whichever documented code, is an UnauthorizedFailure carrying the code', () {
      for (final code in ['not_authenticated', 'session_expired', 'no_refresh_session']) {
        final failure = mapOperationExceptionToFailure(_gql(code));
        expect(failure, isA<UnauthorizedFailure>(), reason: code);
        expect((failure as UnauthorizedFailure).code, code);
      }
    });

    test('the lowercase codes of the contract are recognized, the old uppercase ones are not', () {
      expect(mapOperationExceptionToFailure(_gql('UNAUTHENTICATED')), isA<ServerFailure>());
      expect(mapOperationExceptionToFailure(_gql('FORBIDDEN')), isA<ServerFailure>());
    });

    test('permission_denied is a ForbiddenFailure', () {
      final failure = mapOperationExceptionToFailure(_gql('permission_denied'));
      expect(failure, isA<ForbiddenFailure>());
      expect((failure as ForbiddenFailure).code, 'permission_denied');
    });

    test('a dead session wins over another error in the same response', () {
      final failure = mapOperationExceptionToFailure(
        OperationException(graphqlErrors: [
          const GraphQLError(message: 'a', extensions: {'code': 'insufficient_funds'}),
          const GraphQLError(message: 'b', extensions: {'code': 'not_authenticated'}),
        ]),
      );
      expect(failure, isA<UnauthorizedFailure>());
    });

    test('other codes keep their code and params for the UI to localize', () {
      final failure = mapOperationExceptionToFailure(_gql('insufficient_funds', params: {'available': '40.00'}));
      expect(failure, isA<ServerFailure>());
      failure as ServerFailure;
      expect(failure.code, 'insufficient_funds');
      expect(failure.details['available'], '40.00');
      expect(failure.statusCode, isNull);
    });

    test('validation_failed parses the details JSON string into issues and field errors', () {
      final failure = mapOperationExceptionToFailure(
        _gql('validation_failed', params: {
          'details':
              '[{"traveler": 0, "field": "passportNumber", "code": "required"}, {"traveler": 1, "field": "birthDate", "code": "date_not_future", "max": "2026-10-19"}, {"code": "too_many_files"}]',
        }),
      );
      expect(failure, isA<ValidationFailure>());
      failure as ValidationFailure;
      expect(failure.issues, hasLength(3));
      expect(failure.issues[0], const ValidationIssue(code: 'required', travelerIndex: 0, field: 'passportNumber'));
      expect(failure.issues[1].params, {'max': '2026-10-19'});
      expect(failure.issues[2].field, isNull);
      expect(failure.fieldErrors, {
        'passportNumber': ['required'],
        'birthDate': ['date_not_future'],
      });
    });

    test('a validation_failed with unreadable details still fails cleanly', () {
      final failure = mapOperationExceptionToFailure(_gql('validation_failed', params: {'details': 'not json'}));
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).issues, isEmpty);
    });
  });

  group('transport errors', () {
    OperationException link(LinkException e) => OperationException(linkException: e);

    test('an HTTP 401 or 403 is a server failure with its status, never a session event', () {
      for (final status in [401, 403]) {
        final failure = mapOperationExceptionToFailure(
          link(HttpLinkServerException(
              response: http.Response('', status), parsedResponse: const Response(response: <String, dynamic>{}))),
        );
        expect(failure, isA<ServerFailure>());
        expect((failure as ServerFailure).statusCode, status);
      }
    });

    test('429 and 5xx keep their status and the request id header', () {
      final failure = mapOperationExceptionToFailure(
        link(HttpLinkServerException(
          response: http.Response('', 503, headers: {'x-request-id': 'abc123'}),
          parsedResponse: const Response(response: <String, dynamic>{}),
        )),
      );
      failure as ServerFailure;
      expect(failure.statusCode, 503);
      expect(failure.details['requestId'], 'abc123');
    });

    test('a timeout and a lost connection are NetworkFailures', () {
      final timeout = mapOperationExceptionToFailure(
        link(ServerException(
            originalException: TimeoutException('x'), parsedResponse: const Response(response: <String, dynamic>{}))),
      );
      final offline = mapOperationExceptionToFailure(
        link(const ServerException(
            originalException: SocketException('x'), parsedResponse: Response(response: <String, dynamic>{}))),
      );
      expect(timeout, const NetworkFailure('Request timed out.', isTimeout: true));
      expect(offline, const NetworkFailure('No network connection.'));
    });

    test('unexpected exceptions never put their text into the failure', () {
      final failure = mapOperationExceptionToFailure(
        link(const ServerException(
            originalException: FormatException('passport P1234567'),
            parsedResponse: Response(response: <String, dynamic>{}))),
      );
      expect(failure.message, isNot(contains('P1234567')));
    });
  });
}
