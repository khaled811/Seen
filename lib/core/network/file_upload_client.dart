import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../error/failure.dart';
import 'auth_session_controller.dart';
import 'refresh_coordinator.dart';

/// What `POST /files/upload/` answers with (contract 8.1).
class UploadedFile {
  const UploadedFile({required this.id, required this.fileId, required this.name});

  final String id;
  final String fileId;
  final String name;
}

/// Limits of the upload endpoint, checked here so an obviously wrong file never
/// leaves the device. The server checks again (and decides by the content).
abstract final class UploadLimits {
  static const int maxBytes = 8 * 1024 * 1024;
  static const Map<String, String> contentTypes = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
  };
}

/// `multipart/form-data` uploads to the REST file endpoints.
///
/// - `Content-Length` is always sent (Dio computes it for a [FormData]); the
///   server refuses a chunked upload.
/// - A `401` means the access token is dead: one shared refresh, then the upload
///   is rebuilt (a [FormData] can be sent only once) and sent **once** more. A
///   refresh the server rejects ends the session; one that could not be
///   completed fails as a network error. Never retried beyond that.
/// - Failures carry the server's `error.code` (`file_too_large`,
///   `file_type_not_allowed`, `too_many_files`, ...) so screens can localize them.
/// - The file is streamed from its path: never copied, never kept.
class FileUploadClient {
  FileUploadClient({
    required Dio dio,
    required RefreshCoordinator coordinator,
    required AuthSessionController session,
    required Uri apiBase,
  })  : _dio = dio,
        _coordinator = coordinator,
        _session = session,
        _apiBase = apiBase;

  final Dio _dio;
  final RefreshCoordinator _coordinator;
  final AuthSessionController _session;
  final Uri _apiBase;

  /// A transfer can outlast the 20-second default of ordinary calls.
  static const Duration transferTimeout = Duration(minutes: 2);

  /// The same host as the GraphQL endpoint, with the REST [path] and nothing else.
  Uri _endpoint(String path) =>
      Uri(scheme: _apiBase.scheme, host: _apiBase.host, port: _apiBase.hasPort ? _apiBase.port : null, path: path);

  Future<Either<Failure, UploadedFile>> upload({
    required String kind,
    required String path,
    required String fileName,
    Map<String, String> fields = const {},
    void Function(double fraction)? onProgress,
  }) async {
    final problem = await _check(path, fileName);
    if (problem != null) return Left(ServerFailure('The file was refused locally.', code: problem));
    final result = await _postForm(
      '/files/upload/',
      () async => FormData.fromMap({
        'kind': kind,
        ...fields,
        'file': await MultipartFile.fromFile(
          path,
          filename: fileName,
          contentType: DioMediaType.parse(UploadLimits.contentTypes[_extension(fileName)] ?? 'application/octet-stream'),
        ),
      }),
      isOk: (status) => status == 201,
      onProgress: onProgress,
    );
    return result.flatMap(_parse);
  }

  /// `POST /files/read-passport/` (contract 8.3): a JPEG or PNG of the passport's data page; the
  /// answer is the server's own JSON (`suggestions`, `allChecksPass`). The image is read in memory
  /// by the server and never kept; here it is streamed from [path] and never copied.
  Future<Either<Failure, Map<String, dynamic>>> readPassport({required String path, required String fileName}) async {
    final extension = _extension(fileName);
    if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
      return const Left(ServerFailure('The file is not an image.', code: 'passport_not_image'));
    }
    final problem = await _check(path, fileName);
    if (problem != null) return Left(ServerFailure('The file was refused locally.', code: problem));
    final result = await _postForm(
      '/files/read-passport/',
      () async => FormData.fromMap({
        'file': await MultipartFile.fromFile(
          path,
          filename: fileName,
          contentType: DioMediaType.parse(UploadLimits.contentTypes[extension]!),
        ),
      }),
      isOk: (status) => status == 200 || status == 201,
    );
    return result.flatMap((data) {
      final body = _asMap(data);
      return body == null ? const Left(ServerFailure('Unexpected passport-reading response.')) : Right(body);
    });
  }

  /// One authenticated multipart POST to [path]: the form is rebuilt for the single retry after a
  /// shared token refresh (a [FormData] can be sent only once). Returns the body of an answer
  /// [isOk] accepts.
  Future<Either<Failure, Object?>> _postForm(
    String path,
    Future<FormData> Function() buildForm, {
    required bool Function(int status) isOk,
    void Function(double fraction)? onProgress,
  }) async {
    var refreshed = false;
    while (true) {
      final Response<dynamic> response;
      try {
        response = await _dio.postUri<dynamic>(
          _endpoint(path),
          data: await buildForm(),
          onSendProgress: onProgress == null
              ? null
              : (sent, total) {
                  if (total > 0) onProgress((sent / total).clamp(0.0, 1.0));
                },
          options: Options(
            sendTimeout: transferTimeout,
            receiveTimeout: transferTimeout,
            responseType: ResponseType.json,
          ),
        );
      } on DioException catch (e) {
        return Left(_transportFailure(e));
      } on FileSystemException {
        return const Left(ServerFailure('The file could not be read.', code: 'file_unreadable'));
      }

      final status = response.statusCode ?? 0;
      if (isOk(status)) return Right(response.data);

      final code = _errorCode(response.data);
      if (status == 401 && !refreshed) {
        refreshed = true;
        switch (await _coordinator.refresh()) {
          case RefreshStatus.refreshed:
            continue;
          case RefreshStatus.sessionEnded:
            _session.notifyUnauthenticated();
            return Left(UnauthorizedFailure('The session ended.', code ?? 'not_authenticated'));
          case RefreshStatus.failed:
            return const Left(NetworkFailure('The session could not be refreshed right now.'));
        }
      }
      return Left(_httpFailure(status, code));
    }
  }

  Future<String?> _check(String path, String fileName) async {
    if (!UploadLimits.contentTypes.containsKey(_extension(fileName))) return 'file_type_not_allowed';
    final int size;
    try {
      size = await File(path).length();
    } on FileSystemException {
      return 'file_unreadable';
    }
    if (size == 0) return 'file_empty';
    if (size > UploadLimits.maxBytes) return 'file_too_large';
    return null;
  }

  static String _extension(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static Either<Failure, UploadedFile> _parse(Object? data) {
    final body = _asMap(data);
    final id = body?['id'];
    final fileId = body?['fileId'];
    if (id == null || fileId == null) return const Left(ServerFailure('Unexpected upload response.'));
    return Right(UploadedFile(id: id.toString(), fileId: fileId.toString(), name: body?['name']?.toString() ?? ''));
  }

  static Map<String, dynamic>? _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        return decoded is Map<String, dynamic> ? decoded : null;
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  static String? _errorCode(Object? data) {
    final error = _asMap(data)?['error'];
    final code = error is Map ? error['code'] : null;
    return code is String ? code : null;
  }

  static Failure _httpFailure(int status, String? code) {
    final effective = code ??
        switch (status) {
          413 => 'file_too_large',
          429 => 'too_many_attempts',
          _ => null,
        };
    if (status == 401) return UnauthorizedFailure('Unauthorized', effective);
    if (status == 403 && (effective == null || effective == 'permission_denied')) {
      return ForbiddenFailure('Forbidden', effective);
    }
    return ServerFailure('Upload failed ($status).', statusCode: status, code: effective);
  }

  static Failure _transportFailure(DioException e) {
    final timeout = e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
    return NetworkFailure(timeout ? 'The upload timed out.' : 'No network connection.', isTimeout: timeout);
  }
}
