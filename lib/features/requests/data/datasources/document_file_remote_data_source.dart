import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';

/// Downloads a request file (contract 8.2).
///
/// There is no permanent file URL: `documentDownloadUrl(fileId)` mints a signed
/// link that lives about 90 seconds (and is audited), which is fetched at once on
/// a plain client: no cookies, no bearer token, no cache. The link and the bytes
/// are never stored or logged.
abstract interface class DocumentFileRemoteDataSource {
  /// The signed link of [fileId]. Call it again for every download; never keep it.
  Future<Either<Failure, String>> signedUrl(String fileId);

  /// The bytes behind a signed (or otherwise directly fetchable) HTTPS [url].
  Future<Either<Failure, Uint8List>> fetch(String url);
}

class DocumentFileRemoteDataSourceImpl implements DocumentFileRemoteDataSource {
  DocumentFileRemoteDataSourceImpl({
    GraphQLService? graphQLService,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.maxBytes = 50 * 1024 * 1024,
  })  : _graphQLService = graphQLService,
        _client = client ?? http.Client();

  final GraphQLService? _graphQLService;

  /// A client of its own: it must never carry the session cookie or token to the
  /// storage host.
  final http.Client _client;
  final Duration timeout;

  /// A file larger than this is refused rather than held in memory.
  final int maxBytes;

  static final _downloadUrlDocument = gql(r'''
    mutation DocumentDownloadUrl($fileId: ID!) {
      documentDownloadUrl(fileId: $fileId) { url expiresAt }
    }
  ''');

  @override
  Future<Either<Failure, String>> signedUrl(String fileId) {
    final service = _graphQLService;
    if (service == null) return Future.value(const Left(ServerFailure('Downloads are not available.', code: 'unsupported_operation')));
    return service.mutate<String>(MutationOptions<String>(
      document: _downloadUrlDocument,
      variables: {'fileId': fileId},
      fetchPolicy: FetchPolicy.noCache,
      parserFn: (json) => (json['documentDownloadUrl'] as Map<String, dynamic>)['url'] as String,
    ));
  }

  @override
  Future<Either<Failure, Uint8List>> fetch(String url) async {
    final uri = Uri.tryParse(url);
    // A signed link is always HTTPS: anything else is refused, never fetched.
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return const Left(ServerFailure('Unsupported document URL.', code: 'document_url_invalid'));
    }
    try {
      final response = await _client.send(http.Request('GET', uri)..followRedirects = false).timeout(timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        // An expired or refused link: the caller asks for a new one.
        return Left(ServerFailure('The link was refused.', statusCode: response.statusCode, code: 'document_link_expired'));
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(ServerFailure('Document could not be loaded.', statusCode: response.statusCode));
      }
      final declared = response.contentLength;
      if (declared != null && declared > maxBytes) {
        return const Left(ServerFailure('The file is too large to open.', code: 'file_too_large'));
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(timeout)) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          return const Left(ServerFailure('The file is too large to open.', code: 'file_too_large'));
        }
      }
      if (builder.isEmpty) return Left(ServerFailure('Document is empty.', statusCode: response.statusCode));
      return Right(builder.takeBytes());
    } on TimeoutException {
      return const Left(NetworkFailure('Timed out.', isTimeout: true));
    } on SocketException {
      return const Left(NetworkFailure('No connection.'));
    } on http.ClientException {
      return const Left(NetworkFailure('No connection.'));
    }
  }
}
