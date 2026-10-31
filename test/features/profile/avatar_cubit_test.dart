// The profile photo's state: read once per session, the checks before anything is sent,
// upload progress, a failed upload that can be retried, removal, and clearing at sign-out.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/profile/domain/entities/avatar.dart';
import 'package:seen_booking/features/profile/presentation/bloc/avatar_cubit.dart';

import '../../support/avatar_fakes.dart';

final _bytes = Uint8List.fromList([1, 2, 3]);

void main() {
  test('load reads the address once per session', () async {
    final repo = FakeAvatarRepository()..currentResult = const Right('https://files.example/a.jpg');
    final cubit = AvatarCubit(repo);
    await cubit.load();
    await cubit.load();
    expect(repo.currentCalls, 1);
    expect((cubit.state.url, cubit.state.loaded), ('https://files.example/a.jpg', true));
    await cubit.close();
  });

  test('a failed read leaves it unloaded so the next screen tries again', () async {
    final repo = FakeAvatarRepository()..currentResult = const Left(NetworkFailure('offline'));
    final cubit = AvatarCubit(repo);
    await cubit.load();
    expect(cubit.state.loaded, isFalse);
    repo.currentResult = const Right(null);
    await cubit.load();
    expect((repo.currentCalls, cubit.state.loaded, cubit.state.url), (2, true, null));
    await cubit.close();
  });

  test('a photo over 5 MB or not JPG/PNG is refused before anything is sent', () async {
    final cubit = AvatarCubit(FakeAvatarRepository());
    cubit.reject(const PickedAvatar(path: 'a', fileName: 'a.jpg', sizeBytes: 7 * 1024 * 1024 + 800 * 1024));
    expect(cubit.state.issue?.kind, AvatarIssueKind.tooLarge);
    expect(cubit.state.issue?.sizeBytes, greaterThan(PickedAvatar.maxBytes));
    cubit.reject(const PickedAvatar(path: 'a', fileName: 'a.gif', sizeBytes: 10));
    expect(cubit.state.issue?.kind, AvatarIssueKind.wrongType);
    expect(const PickedAvatar(path: 'a', fileName: 'A.PNG', sizeBytes: 10).isAllowedType, isTrue);
    expect(const PickedAvatar(path: 'a', fileName: 'noext', sizeBytes: 10).isAllowedType, isFalse);
    await cubit.close();
  });

  test('upload reports progress, then the new address and an "updated" event', () async {
    final repo = FakeAvatarRepository()
      ..progress = const [.25, .64]
      ..hold = Completer<void>();
    final cubit = AvatarCubit(repo);
    final states = <AvatarState>[];
    final sub = cubit.stream.listen(states.add);
    final sending = cubit.upload(_bytes);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.uploading, isTrue);
    expect(cubit.state.progress, .64);
    expect(cubit.state.sizeBytes, 3);
    repo.hold!.complete();
    await sending;
    expect(cubit.state.uploading, isFalse);
    expect((cubit.state.url, cubit.state.event), ('https://files.example/avatar.png', AvatarEvent.updated));
    cubit.eventShown();
    expect(cubit.state.event, isNull);
    await sub.cancel();
    await cubit.close();
  });

  test('a second upload while one is running is ignored', () async {
    final repo = FakeAvatarRepository()..hold = Completer<void>();
    final cubit = AvatarCubit(repo);
    final first = cubit.upload(_bytes);
    await Future<void>.delayed(Duration.zero);
    await cubit.upload(_bytes);
    expect(repo.uploads, hasLength(1));
    repo.hold!.complete();
    await first;
    await cubit.close();
  });

  test('a network failure keeps the old photo, flags the upload, and retry sends the same photo again', () async {
    final repo = FakeAvatarRepository()
      ..currentResult = const Right('https://files.example/old.jpg')
      ..uploadResult = const Left(NetworkFailure('offline'));
    final cubit = AvatarCubit(repo);
    await cubit.load();
    await cubit.upload(_bytes);
    expect(cubit.state.url, 'https://files.example/old.jpg');
    expect(cubit.state.issue?.kind, AvatarIssueKind.offline);
    expect(cubit.state.uploading, isFalse);

    repo.uploadResult = const Right('https://files.example/new.png');
    await cubit.retry();
    expect(repo.uploads, hasLength(2));
    expect(repo.uploads.last, _bytes);
    expect((cubit.state.url, cubit.state.issue), ('https://files.example/new.png', null));
    await cubit.close();
  });

  test('server codes become the right issue', () {
    expect(AvatarIssue.from(const ServerFailure('x', code: 'avatar_type_invalid')).kind, AvatarIssueKind.wrongType);
    expect(AvatarIssue.from(const ServerFailure('x', code: 'file_too_large')).kind, AvatarIssueKind.tooLarge);
    expect(AvatarIssue.from(const ServerFailure('x', code: 'CAMERA_PERMISSION_DENIED')).kind, AvatarIssueKind.cameraDenied);
    expect(AvatarIssue.from(const ServerFailure('x', code: 'boom')).kind, AvatarIssueKind.generic);
  });

  test('remove clears the photo and says "deleted"; a failure keeps it', () async {
    final repo = FakeAvatarRepository()..currentResult = const Right('https://files.example/a.jpg');
    final cubit = AvatarCubit(repo);
    await cubit.load();
    repo.removeResult = const Left(NetworkFailure('offline'));
    await cubit.remove();
    expect(cubit.state.url, 'https://files.example/a.jpg');
    expect(cubit.state.issue?.kind, AvatarIssueKind.offline);
    repo.removeResult = const Right(null);
    await cubit.remove();
    expect((cubit.state.url, cubit.state.event), (null, AvatarEvent.deleted));
    await cubit.close();
  });

  test('clear forgets everything when the session ends', () async {
    final repo = FakeAvatarRepository()..currentResult = const Right('https://files.example/a.jpg');
    final cubit = AvatarCubit(repo);
    await cubit.load();
    cubit.clear();
    expect(cubit.state, const AvatarState());
    await cubit.load();
    expect(repo.currentCalls, 2, reason: 'the next person reads their own photo');
    await cubit.close();
  });
}
