import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/file_upload_client.dart';
import '../../../../core/services/staged_file_uploader.dart';
import '../../domain/entities/missing_document.dart';
import '../../domain/services/document_picker.dart';

/// Why a picked file was not taken.
enum StagedAttachmentIssue { tooLarge, wrongType, unavailable, cameraDenied, photosDenied }

class StagedAttachmentState extends Equatable {
  const StagedAttachmentState({
    this.file,
    this.fileId,
    this.uploading = false,
    this.progress = 0,
    this.failure,
    this.issue,
  });

  /// The file picked (name and size only are shown; the path is not kept past the upload).
  final PickedDocument? file;

  /// Set once the server holds the file: this is what the next call refers to.
  final String? fileId;
  final bool uploading;
  final double progress;
  final Failure? failure;
  final StagedAttachmentIssue? issue;

  bool get isAttached => fileId != null;

  @override
  List<Object?> get props => [file, fileId, uploading, progress, failure, issue];
}

/// One optional attachment that is sent as soon as it is picked (a top-up
/// receipt, a ticket file) and then referred to by id. Owner: the screen that
/// provides it. Everything is in memory; the file is streamed from its path.
class StagedAttachmentCubit extends Cubit<StagedAttachmentState> {
  /// [picker] and [uploader] are resolved on first use, so nothing is created
  /// until a file is picked.
  StagedAttachmentCubit({required DocumentPicker Function() picker, required StagedFileUploader Function() uploader})
      : _picker = picker,
        _uploader = uploader,
        super(const StagedAttachmentState());

  final DocumentPicker Function() _picker;
  final StagedFileUploader Function() _uploader;
  bool _busy = false;

  static const allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];

  Future<void> pick(DocumentSource source) async {
    if (_busy) return; // a double tap while the picker or the upload runs
    _busy = true;
    try {
      final picked = await _picker().pick(source, allowedExtensions: allowedExtensions);
      if (isClosed) return;
      final document = picked.fold<PickedDocument?>((failure) {
        emit(StagedAttachmentState(
          file: state.file,
          fileId: state.fileId,
          issue: switch (failure is ServerFailure ? failure.code : null) {
            cameraDeniedCode => StagedAttachmentIssue.cameraDenied,
            photosDeniedCode => StagedAttachmentIssue.photosDenied,
            _ => StagedAttachmentIssue.unavailable,
          },
        ));
        return null;
      }, (doc) => doc);
      if (document == null) return; // failed or cancelled

      if (!allowedExtensions.contains(document.extension)) {
        emit(StagedAttachmentState(file: state.file, fileId: state.fileId, issue: StagedAttachmentIssue.wrongType));
        return;
      }
      if (document.sizeBytes > UploadLimits.maxBytes) {
        emit(StagedAttachmentState(file: state.file, fileId: state.fileId, issue: StagedAttachmentIssue.tooLarge));
        return;
      }

      emit(StagedAttachmentState(file: document, uploading: true));
      final result = await _uploader().stage(
        path: document.path,
        fileName: document.fileName,
        onProgress: (fraction) {
          if (!isClosed && state.uploading) {
            emit(StagedAttachmentState(file: document, uploading: true, progress: fraction));
          }
        },
      );
      if (isClosed) return;
      emit(
        result.fold(
          // The previous attachment (if any) was replaced by this attempt: nothing is attached now.
          (failure) => StagedAttachmentState(failure: failure),
          (id) => StagedAttachmentState(file: document, fileId: id),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  /// Drops the attachment. The server deletes an unattached staged file by itself.
  void remove() {
    if (state.uploading) return;
    emit(const StagedAttachmentState());
  }
}
