import 'dart:io';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../../../core/services/staged_file_uploader.dart';
import '../../domain/repositories/avatar_repository.dart';

/// `me { avatarUrl }`, the upload (`POST /files/upload/`, staged) followed by
/// `setMyAvatar(fileId)`, and `removeMyAvatar`.
class AvatarRemoteDataSource implements AvatarRepository {
  AvatarRemoteDataSource({
    required GraphQLService graphQLService,
    required StagedFileUploader uploader,
    Future<Directory> Function()? tempDirectory,
  })  : _graphQL = graphQLService,
        _uploader = uploader,
        _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final GraphQLService _graphQL;
  final StagedFileUploader _uploader;
  final Future<Directory> Function() _tempDirectory;

  static final _currentDoc = gql(r'''
    query MyAvatar { me { avatarUrl } }
  ''');

  static final _setDoc = gql(r'''
    mutation SetMyAvatar($fileId: ID!) { setMyAvatar(fileId: $fileId) { avatarUrl } }
  ''');

  static final _removeDoc = gql(r'''
    mutation RemoveMyAvatar { removeMyAvatar { avatarUrl } }
  ''');

  static String? _urlOf(Map<String, dynamic> json, String field) => (json[field] as Map<String, dynamic>)['avatarUrl'] as String?;

  @override
  Future<Either<Failure, String?>> currentUrl() => _graphQL.query<String?>(QueryOptions<String?>(
        document: _currentDoc,
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (j) => _urlOf(j, 'me'),
      ));

  @override
  Future<Either<Failure, String?>> upload(Uint8List bytes, {required String fileName, void Function(double fraction)? onProgress}) async {
    // The cropped photo goes through a temporary file (the uploader reads from a path) that is
    // deleted as soon as the upload ended, whatever the result.
    final dir = await _tempDirectory();
    final file = File('${dir.path}/seen-avatar-${DateTime.now().microsecondsSinceEpoch}.${fileName.split('.').last}');
    try {
      await file.writeAsBytes(bytes, flush: true);
      final staged = await _uploader.stage(path: file.path, fileName: fileName, onProgress: onProgress);
      return await staged.fold(
        (f) async => Left(f),
        (fileId) => _graphQL.mutate<String?>(MutationOptions<String?>(
          document: _setDoc,
          variables: {'fileId': fileId},
          fetchPolicy: FetchPolicy.noCache,
          parserFn: (j) => _urlOf(j, 'setMyAvatar'),
        )),
      );
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  @override
  Future<Either<Failure, void>> remove() async => (await _graphQL.mutate<String?>(MutationOptions<String?>(
        document: _removeDoc,
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) => _urlOf(j, 'removeMyAvatar'),
      )))
          .map((_) {});
}
