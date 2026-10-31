// Downloads (contract 8.2): a signed link is asked for each time, fetched at once
// on a plain client over HTTPS, bounded in size, and never reused or stored.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/requests/data/datasources/document_file_remote_data_source.dart';
import 'package:seen_booking/features/requests/data/repositories/document_file_repository_impl.dart';

import '../../../support/scripted_graphql_service.dart';

http.Response _ok(List<int> bytes) => http.Response.bytes(bytes, 200);

void main() {
  group('the signed link', () {
    test('is requested with documentDownloadUrl(fileId) and nothing else', () async {
      final graphql = ScriptedGraphQLService({
        'DocumentDownloadUrl': {
          'documentDownloadUrl': {'url': 'https://files.seen.test/x?sig=abc', 'expiresAt': '2026-10-19T10:01:30+00:00'},
        },
      });
      final source = DocumentFileRemoteDataSourceImpl(graphQLService: graphql, client: MockClient((_) async => _ok([1])));
      final result = await source.signedUrl('file-1');
      expect((result as Right).value, 'https://files.seen.test/x?sig=abc');
      expect(graphql.where('DocumentDownloadUrl').single.variables, {'fileId': 'file-1'});
    });

    test('a refusal is a failure with the server code', () async {
      final graphql = ScriptedGraphQLService({'DocumentDownloadUrl': const ServerFailure('x', code: 'file_not_found')});
      final source = DocumentFileRemoteDataSourceImpl(graphQLService: graphql);
      final failure = ((await source.signedUrl('file-1')) as Left).value as ServerFailure;
      expect(failure.code, 'file_not_found');
    });
  });

  group('fetching the bytes', () {
    test('only over https; nothing else is even attempted', () async {
      var calls = 0;
      final source = DocumentFileRemoteDataSourceImpl(client: MockClient((_) async {
        calls++;
        return _ok([1]);
      }));
      for (final url in ['http://files.seen.test/x', 'ftp://x/y', 'file:///etc/passwd', 'not a url', 'https://']) {
        final result = await source.fetch(url);
        expect(((result as Left).value as ServerFailure).code, 'document_url_invalid', reason: url);
      }
      expect(calls, 0);
    });

    test('sends no cookie and no token to the storage host, and does not follow redirects', () async {
      late http.BaseRequest seen;
      final source = DocumentFileRemoteDataSourceImpl(client: MockClient.streaming((request, body) async {
        seen = request;
        return http.StreamedResponse(Stream.value([1, 2, 3]), 200);
      }));
      final result = await source.fetch('https://files.seen.test/x?sig=abc');
      expect((result as Right).value, [1, 2, 3]);
      expect(seen.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
      expect(seen.headers.keys.map((k) => k.toLowerCase()), isNot(contains('cookie')));
      expect(seen.followRedirects, isFalse);
    });

    test('an expired or refused link says so (the caller asks for a new one)', () async {
      for (final status in [401, 403]) {
        final source = DocumentFileRemoteDataSourceImpl(client: MockClient((_) async => http.Response('', status)));
        final failure = ((await source.fetch('https://files.seen.test/x')) as Left).value as ServerFailure;
        expect(failure.code, 'document_link_expired', reason: '$status');
      }
    });

    test('other statuses and an empty body are failures', () async {
      final notFound = DocumentFileRemoteDataSourceImpl(client: MockClient((_) async => http.Response('', 404)));
      expect(((await notFound.fetch('https://x.test/a')) as Left).value, isA<ServerFailure>());
      final empty = DocumentFileRemoteDataSourceImpl(client: MockClient((_) async => _ok(const [])));
      expect(((await empty.fetch('https://x.test/a')) as Left).value, isA<ServerFailure>());
    });

    test('a file over the limit is refused, declared or streamed', () async {
      final declared = DocumentFileRemoteDataSourceImpl(
        maxBytes: 10,
        client: MockClient.streaming((r, b) async => http.StreamedResponse(Stream.value(List.filled(5, 1)), 200, contentLength: 11)),
      );
      expect((((await declared.fetch('https://x.test/a')) as Left).value as ServerFailure).code, 'file_too_large');

      final streamed = DocumentFileRemoteDataSourceImpl(
        maxBytes: 10,
        client: MockClient.streaming((r, b) async => http.StreamedResponse(Stream.fromIterable([List.filled(6, 1), List.filled(6, 1)]), 200)),
      );
      expect((((await streamed.fetch('https://x.test/a')) as Left).value as ServerFailure).code, 'file_too_large');

      final fits = DocumentFileRemoteDataSourceImpl(maxBytes: 12, client: MockClient((_) async => _ok(List.filled(12, 1))));
      expect((await fits.fetch('https://x.test/a')).isRight(), isTrue);
    });

    test('no connection and a stalled download are network failures', () async {
      final offline = DocumentFileRemoteDataSourceImpl(client: MockClient((_) async => throw http.ClientException('down')));
      expect(((await offline.fetch('https://x.test/a')) as Left).value, isA<NetworkFailure>());

      final stalled = DocumentFileRemoteDataSourceImpl(
        timeout: const Duration(milliseconds: 20),
        client: MockClient.streaming((r, b) async => http.StreamedResponse(Completer<Uint8List>().future.asStream(), 200)),
      );
      final failure = ((await stalled.fetch('https://x.test/a')) as Left).value as NetworkFailure;
      expect(failure.isTimeout, isTrue);
    });
  });

  group('by file id', () {
    test('asks for a link and fetches it', () async {
      final graphql = ScriptedGraphQLService({
        'DocumentDownloadUrl': {
          'documentDownloadUrl': {'url': 'https://files.seen.test/x', 'expiresAt': '2026-10-19T10:01:30+00:00'},
        },
      });
      final repo = DocumentFileRepositoryImpl(
        remote: DocumentFileRemoteDataSourceImpl(graphQLService: graphql, client: MockClient((_) async => _ok([9, 9]))),
      );
      expect(((await repo.fetchFile('file-1')) as Right).value, [9, 9]);
      expect(graphql.where('DocumentDownloadUrl'), hasLength(1));
    });

    test('a link that had already expired is replaced once, then the answer stands', () async {
      final graphql = ScriptedGraphQLService({
        'DocumentDownloadUrl': {
          'documentDownloadUrl': {'url': 'https://files.seen.test/x', 'expiresAt': '2026-10-19T10:01:30+00:00'},
        },
      });
      var fetches = 0;
      final repo = DocumentFileRepositoryImpl(
        remote: DocumentFileRemoteDataSourceImpl(
          graphQLService: graphql,
          client: MockClient((_) async => ++fetches == 1 ? http.Response('', 403) : _ok([5])),
        ),
      );
      expect(((await repo.fetchFile('file-1')) as Right).value, [5]);
      expect(graphql.where('DocumentDownloadUrl'), hasLength(2)); // a new link for the second try

      fetches = 0;
      final stubborn = DocumentFileRepositoryImpl(
        remote: DocumentFileRemoteDataSourceImpl(graphQLService: graphql, client: MockClient((_) async => http.Response('', 403))),
      );
      final failure = ((await stubborn.fetchFile('file-1')) as Left).value as ServerFailure;
      expect(failure.code, 'document_link_expired');
      expect(graphql.where('DocumentDownloadUrl'), hasLength(4)); // two more, never a third
    });

    test('a link request that fails ends there, nothing is fetched', () async {
      final graphql = ScriptedGraphQLService({'DocumentDownloadUrl': const NetworkFailure('off')});
      var fetches = 0;
      final repo = DocumentFileRepositoryImpl(
        remote: DocumentFileRemoteDataSourceImpl(graphQLService: graphql, client: MockClient((_) async {
          fetches++;
          return _ok([1]);
        })),
      );
      expect(((await repo.fetchFile('file-1')) as Left).value, isA<NetworkFailure>());
      expect(fetches, 0);
    });
  });
}
