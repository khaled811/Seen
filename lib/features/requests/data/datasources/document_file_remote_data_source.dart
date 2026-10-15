import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;

import '../../../../core/error/failure.dart';

/// Downloads a request document.
///
/// TODO(backend-contract): assumes `outputDocumentUrl` is a directly fetchable
/// (pre-signed, time-limited) HTTPS URL; no auth header is sent
/// (docs/BACKEND_MIGRATION_GAPS.md, section 13).
abstract interface class DocumentFileRemoteDataSource {
  Future<Either<Failure, Uint8List>> fetch(String url);
}

class DocumentFileRemoteDataSourceImpl implements DocumentFileRemoteDataSource {
  DocumentFileRemoteDataSourceImpl({http.Client? client, this.timeout = const Duration(seconds: 30)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<Either<Failure, Uint8List>> fetch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return const Left(ServerFailure('Unsupported document URL.', code: 'DOCUMENT_URL_INVALID'));
    }
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode == 401) return const Left(UnauthorizedFailure());
      if (response.statusCode < 200 || response.statusCode >= 300 || response.bodyBytes.isEmpty) {
        return Left(ServerFailure('Document could not be loaded.', statusCode: response.statusCode));
      }
      return Right(response.bodyBytes);
    } on TimeoutException {
      return const Left(NetworkFailure('Timed out.'));
    } on SocketException {
      return const Left(NetworkFailure('No connection.'));
    } on http.ClientException {
      return const Left(NetworkFailure('No connection.'));
    }
  }
}
