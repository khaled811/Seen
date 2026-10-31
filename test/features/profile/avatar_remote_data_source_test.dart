// The profile photo against the contract: the documents are validated against
// `docs/api/mobile-api-reference.md`; the cropped photo is staged from a temporary file that is
// deleted whatever the result, and `setMyAvatar` gets the staged file's id.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/services/staged_file_uploader.dart';
import 'package:seen_booking/features/profile/data/datasources/avatar_remote_data_source.dart';

import '../../support/scripted_graphql_service.dart';

class _Uploader implements StagedFileUploader {
  _Uploader(this.result);

  Either<Failure, String> result;
  String? path;
  bool existedWhenStaged = false;
  Uint8List? content;

  @override
  Future<Either<Failure, String>> stage({required String path, required String fileName, void Function(double fraction)? onProgress}) async {
    this.path = path;
    existedWhenStaged = File(path).existsSync();
    content = File(path).readAsBytesSync();
    onProgress?.call(.5);
    return result;
  }
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('avatar_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  AvatarRemoteDataSource make(ScriptedGraphQLService graphql, _Uploader uploader) =>
      AvatarRemoteDataSource(graphQLService: graphql, uploader: uploader, tempDirectory: () async => dir);

  test('currentUrl reads `me.avatarUrl`, null when there is no photo', () async {
    final graphql = ScriptedGraphQLService({
      'MyAvatar': {
        'me': {'avatarUrl': null},
      },
    });
    expect(await make(graphql, _Uploader(const Right('f'))).currentUrl(), const Right<Failure, String?>(null));
  });

  test('upload stages the photo from a temp file, sets it by file id, and deletes the file', () async {
    final graphql = ScriptedGraphQLService({
      'SetMyAvatar': {
        'setMyAvatar': {'avatarUrl': 'https://files.example/new.png'},
      },
    });
    final uploader = _Uploader(const Right('file-77'));
    final progress = <double>[];
    final result = await make(graphql, uploader).upload(Uint8List.fromList([9, 8, 7]), fileName: 'profile.png', onProgress: progress.add);
    expect(result, const Right<Failure, String?>('https://files.example/new.png'));
    expect(uploader.existedWhenStaged, isTrue);
    expect(uploader.content, [9, 8, 7]);
    expect(progress, [.5]);
    expect(graphql.where('SetMyAvatar').single.variables, {'fileId': 'file-77'});
    expect(File(uploader.path!).existsSync(), isFalse, reason: 'no copy of the photo is left on the device');
    expect(dir.listSync(), isEmpty);
  });

  test('a failed upload sends no setMyAvatar and still removes the temp file', () async {
    final graphql = ScriptedGraphQLService({});
    final uploader = _Uploader(const Left(NetworkFailure('offline')));
    final result = await make(graphql, uploader).upload(Uint8List.fromList([1]), fileName: 'profile.png');
    expect(result.isLeft(), isTrue);
    expect(graphql.sent, isEmpty);
    expect(dir.listSync(), isEmpty);
  });

  test('remove calls removeMyAvatar', () async {
    final graphql = ScriptedGraphQLService({
      'RemoveMyAvatar': {
        'removeMyAvatar': {'avatarUrl': null},
      },
    });
    expect((await make(graphql, _Uploader(const Right('f'))).remove()).isRight(), isTrue);
    expect(graphql.where('RemoveMyAvatar'), hasLength(1));
  });
}
