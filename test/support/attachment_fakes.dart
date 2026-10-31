import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/services/staged_file_uploader.dart';
import 'package:seen_booking/features/requests/domain/entities/missing_document.dart';
import 'package:seen_booking/features/requests/domain/services/document_picker.dart';
import 'package:seen_booking/features/requests/presentation/bloc/staged_attachment_cubit.dart';

/// A picker that always "picks" the same small file.
class FakeDocumentPicker implements DocumentPicker {
  @override
  Future<Either<Failure, PickedDocument?>> pick(DocumentSource source, {required List<String> allowedExtensions}) async =>
      const Right(PickedDocument(path: '/tmp/proof.pdf', fileName: 'proof.pdf', sizeBytes: 4096));
}

/// A stager that records what it was given and answers with [id] (or a failure).
class FakeStagedUploader implements StagedFileUploader {
  FakeStagedUploader({this.id = 'staged-1', this.failure});

  final String id;
  final Failure? failure;
  final staged = <String>[];

  @override
  Future<Either<Failure, String>> stage({required String path, required String fileName, void Function(double fraction)? onProgress}) async {
    staged.add(path);
    return failure == null ? Right(id) : Left(failure!);
  }
}

StagedAttachmentCubit fakeAttachmentCubit(FakeStagedUploader uploader) =>
    StagedAttachmentCubit(picker: FakeDocumentPicker.new, uploader: () => uploader);
