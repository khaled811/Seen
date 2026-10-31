// An attachment that is sent as soon as it is picked and then referred to by id
// (top-up receipt): limits, failures, replacing, and no double work.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/services/staged_file_uploader.dart';
import 'package:seen_booking/features/requests/domain/entities/missing_document.dart';
import 'package:seen_booking/features/requests/domain/services/document_picker.dart';
import 'package:seen_booking/features/requests/presentation/bloc/staged_attachment_cubit.dart';

const _receipt = PickedDocument(path: '/tmp/receipt.jpg', fileName: 'receipt.jpg', sizeBytes: 2048);

class _Picker implements DocumentPicker {
  Either<Failure, PickedDocument?> result = const Right(_receipt);
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<Either<Failure, PickedDocument?>> pick(DocumentSource source, {required List<String> allowedExtensions}) async {
    calls++;
    await gate?.future;
    return result;
  }
}

class _Uploader implements StagedFileUploader {
  Either<Failure, String> result = const Right('file-1');
  Completer<void>? gate;
  final staged = <String>[];

  @override
  Future<Either<Failure, String>> stage({
    required String path,
    required String fileName,
    void Function(double fraction)? onProgress,
  }) async {
    staged.add(path);
    onProgress?.call(0.5);
    await gate?.future;
    return result;
  }
}

StagedAttachmentCubit _cubit(_Picker p, _Uploader u) => StagedAttachmentCubit(picker: () => p, uploader: () => u);

void main() {
  late _Picker picker;
  late _Uploader uploader;
  late StagedAttachmentCubit cubit;

  setUp(() {
    picker = _Picker();
    uploader = _Uploader();
    cubit = _cubit(picker, uploader);
  });

  tearDown(() => cubit.close());

  test('a picked file is sent at once and its id is what the request refers to', () async {
    final states = <StagedAttachmentState>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.pick(DocumentSource.gallery);
    await pumpEventQueue();
    await sub.cancel();

    expect(uploader.staged, ['/tmp/receipt.jpg']);
    expect(states.first.uploading, isTrue);
    expect(states.any((s) => s.progress == 0.5), isTrue);
    expect(cubit.state.fileId, 'file-1');
    expect(cubit.state.isAttached, isTrue);
    expect(cubit.state.uploading, isFalse);
    expect(cubit.state.file, _receipt);
  });

  test('a file of a type the server does not take is never sent', () async {
    picker.result = const Right(PickedDocument(path: '/x.svg', fileName: 'x.svg', sizeBytes: 10));
    await cubit.pick(DocumentSource.file);
    expect(cubit.state.issue, StagedAttachmentIssue.wrongType);
    expect(cubit.state.file, isNull);
    expect(uploader.staged, isEmpty);
  });

  test('a file over 8 MiB is never sent; exactly 8 MiB is', () async {
    picker.result = const Right(PickedDocument(path: '/b.jpg', fileName: 'b.jpg', sizeBytes: 8 * 1024 * 1024 + 1));
    await cubit.pick(DocumentSource.file);
    expect(cubit.state.issue, StagedAttachmentIssue.tooLarge);
    expect(uploader.staged, isEmpty);

    picker.result = const Right(PickedDocument(path: '/b.jpg', fileName: 'b.jpg', sizeBytes: 8 * 1024 * 1024));
    await cubit.pick(DocumentSource.file);
    expect(cubit.state.isAttached, isTrue);
  });

  test('a refused file keeps what was attached before', () async {
    await cubit.pick(DocumentSource.file);
    picker.result = const Right(PickedDocument(path: '/x.exe', fileName: 'x.exe', sizeBytes: 10));
    await cubit.pick(DocumentSource.file);
    expect(cubit.state.issue, StagedAttachmentIssue.wrongType);
    expect(cubit.state.fileId, 'file-1');
  });

  test('cancelling the picker changes nothing', () async {
    picker.result = const Right(null);
    await cubit.pick(DocumentSource.file);
    expect(cubit.state, const StagedAttachmentState());
  });

  test('a permission refused for good is reported as such', () async {
    picker.result = const Left(ServerFailure('denied', code: cameraDeniedCode));
    await cubit.pick(DocumentSource.camera);
    expect(cubit.state.issue, StagedAttachmentIssue.cameraDenied);
    picker.result = const Left(ServerFailure('denied', code: photosDeniedCode));
    await cubit.pick(DocumentSource.gallery);
    expect(cubit.state.issue, StagedAttachmentIssue.photosDenied);
    picker.result = const Left(ServerFailure('x', code: 'PICKER_UNAVAILABLE'));
    await cubit.pick(DocumentSource.file);
    expect(cubit.state.issue, StagedAttachmentIssue.unavailable);
  });

  test('an upload the server refuses attaches nothing and says why', () async {
    uploader.result = const Left(ServerFailure('x', code: 'file_content_mismatch'));
    await cubit.pick(DocumentSource.file);
    expect(cubit.state.fileId, isNull);
    expect((cubit.state.failure as ServerFailure).code, 'file_content_mismatch');
    expect(cubit.state.isAttached, isFalse);

    // Another try works.
    uploader.result = const Right('file-2');
    await cubit.pick(DocumentSource.file);
    expect(cubit.state.fileId, 'file-2');
    expect(cubit.state.failure, isNull);
  });

  test('no connection while sending is a network failure; nothing is attached', () async {
    uploader.result = const Left(NetworkFailure('off'));
    await cubit.pick(DocumentSource.file);
    expect(cubit.state.failure, isA<NetworkFailure>());
    expect(cubit.state.isAttached, isFalse);
  });

  test('a second tap while the picker or the upload runs is ignored', () async {
    final gate = uploader.gate = Completer<void>();
    final first = cubit.pick(DocumentSource.file);
    await pumpEventQueue();
    expect(cubit.state.uploading, isTrue);
    await cubit.pick(DocumentSource.file); // ignored
    expect(picker.calls, 1);
    gate.complete();
    await first;
    expect(uploader.staged, hasLength(1));
  });

  test('remove clears the attachment, but not while it is being sent', () async {
    await cubit.pick(DocumentSource.file);
    cubit.remove();
    expect(cubit.state, const StagedAttachmentState());

    final gate = uploader.gate = Completer<void>();
    final pending = cubit.pick(DocumentSource.file);
    await pumpEventQueue();
    cubit.remove();
    expect(cubit.state.uploading, isTrue);
    gate.complete();
    await pending;
    expect(cubit.state.isAttached, isTrue);
  });

  test('closing while the upload runs does not emit afterwards', () async {
    final gate = uploader.gate = Completer<void>();
    final pending = cubit.pick(DocumentSource.file);
    await pumpEventQueue();
    await cubit.close();
    gate.complete();
    await pending; // completes without throwing "emit after close"
  });
}
