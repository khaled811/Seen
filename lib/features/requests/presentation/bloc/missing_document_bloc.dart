import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/services/pending_uploads.dart';
import '../../domain/entities/missing_document.dart';
import '../../domain/services/document_picker.dart' show cameraDeniedCode, photosDeniedCode;
import '../../domain/usecases/missing_document_usecases.dart';

sealed class MissingDocumentEvent extends Equatable {
  const MissingDocumentEvent();

  @override
  List<Object?> get props => [];
}

final class MissingDocumentStarted extends MissingDocumentEvent {
  const MissingDocumentStarted(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

final class MissingDocumentSourceChosen extends MissingDocumentEvent {
  const MissingDocumentSourceChosen(this.source);

  final DocumentSource source;

  @override
  List<Object?> get props => [source];
}

final class MissingDocumentRemoved extends MissingDocumentEvent {
  const MissingDocumentRemoved();
}

final class MissingDocumentSubmitted extends MissingDocumentEvent {
  const MissingDocumentSubmitted();
}

final class MissingDocumentIssueDismissed extends MissingDocumentEvent {
  const MissingDocumentIssueDismissed();
}

final class _ProgressChanged extends MissingDocumentEvent {
  const _ProgressChanged(this.fraction);

  final double fraction;

  @override
  List<Object?> get props => [fraction];
}

enum MissingDocumentStatus { loading, ready, loadFailed }

class MissingDocumentState extends Equatable {
  const MissingDocumentState({
    this.status = MissingDocumentStatus.loading,
    this.request,
    this.picked,
    this.uploading = false,
    this.progress = 0,
    this.issue,
    this.submitted = false,
  });

  final MissingDocumentStatus status;
  final MissingDocumentRequest? request;
  final PickedDocument? picked;
  final bool uploading;

  /// 0..1, 0 while the transport has not reported anything yet.
  final double progress;
  final DocumentIssue? issue;
  final bool submitted;

  bool get deadlinePassed => issue?.kind == DocumentIssueKind.deadlinePassed;

  MissingDocumentState copyWith({
    MissingDocumentStatus? status,
    MissingDocumentRequest? request,
    PickedDocument? picked,
    bool clearPicked = false,
    bool? uploading,
    double? progress,
    DocumentIssue? issue,
    bool clearIssue = false,
    bool? submitted,
  }) =>
      MissingDocumentState(
        status: status ?? this.status,
        request: request ?? this.request,
        picked: clearPicked ? null : (picked ?? this.picked),
        uploading: uploading ?? this.uploading,
        progress: progress ?? this.progress,
        issue: clearIssue ? null : (issue ?? this.issue),
        submitted: submitted ?? this.submitted,
      );

  @override
  List<Object?> get props => [status, request, picked, uploading, progress, issue, submitted];
}

class MissingDocumentBloc extends Bloc<MissingDocumentEvent, MissingDocumentState> {
  MissingDocumentBloc({
    required GetMissingDocumentUseCase getMissingDocument,
    required UploadMissingDocumentUseCase uploadDocument,
    required PickDocumentUseCase pickDocument,
    DateTime Function() clock = DateTime.now,
    PendingUploads? pendingUploads,
  })  : _pending = pendingUploads,
        _get = getMissingDocument,
        _upload = uploadDocument,
        _pick = pickDocument,
        _clock = clock,
        super(const MissingDocumentState()) {
    on<MissingDocumentStarted>(_onStarted, transformer: restartable());
    on<MissingDocumentSourceChosen>(_onSource, transformer: droppable());
    on<MissingDocumentRemoved>(
      (event, emit) => emit(state.copyWith(clearPicked: true, clearIssue: true, progress: 0)),
    );
    on<MissingDocumentSubmitted>(_onSubmitted, transformer: droppable());
    on<MissingDocumentIssueDismissed>((event, emit) => emit(state.copyWith(clearIssue: true)));
    on<_ProgressChanged>((event, emit) => emit(state.copyWith(progress: event.fraction)));
  }

  final GetMissingDocumentUseCase _get;
  final UploadMissingDocumentUseCase _upload;
  final PickDocumentUseCase _pick;
  final DateTime Function() _clock;
  final PendingUploads? _pending;

  Future<void> _onStarted(MissingDocumentStarted event, Emitter<MissingDocumentState> emit) async {
    emit(const MissingDocumentState());
    final result = await _get(event.requestId);
    result.match(
      (failure) => emit(const MissingDocumentState(
        status: MissingDocumentStatus.loadFailed,
        issue: DocumentIssue(DocumentIssueKind.loadFailed),
      )),
      (request) => emit(MissingDocumentState(
        status: MissingDocumentStatus.ready,
        request: request,
        issue: request.deadline.isAfter(_clock()) ? null : const DocumentIssue(DocumentIssueKind.deadlinePassed),
      )),
    );
  }

  Future<void> _onSource(MissingDocumentSourceChosen event, Emitter<MissingDocumentState> emit) async {
    final request = state.request;
    if (request == null || state.uploading || state.deadlinePassed) return;
    final result = await _pick(event.source, allowedExtensions: request.allowedExtensions);
    result.match(
      (failure) => emit(state.copyWith(
        issue: DocumentIssue(switch (failure is ServerFailure ? failure.code : null) {
          cameraDeniedCode => DocumentIssueKind.cameraDenied,
          photosDeniedCode => DocumentIssueKind.photosDenied,
          _ => DocumentIssueKind.pickerUnavailable,
        }),
      )),
      (doc) {
        if (doc == null) return; // cancelled
        if (!request.allowedExtensions.contains(doc.extension)) {
          emit(state.copyWith(issue: const DocumentIssue(DocumentIssueKind.wrongType)));
        } else if (doc.sizeBytes > request.maxBytes) {
          emit(state.copyWith(issue: const DocumentIssue(DocumentIssueKind.tooLarge)));
        } else {
          emit(state.copyWith(picked: doc, clearIssue: true, progress: 0));
        }
      },
    );
  }

  Future<void> _onSubmitted(MissingDocumentSubmitted event, Emitter<MissingDocumentState> emit) async {
    final request = state.request;
    final doc = state.picked;
    if (request == null || doc == null || state.deadlinePassed) return;
    if (!request.deadline.isAfter(_clock())) {
      emit(state.copyWith(issue: const DocumentIssue(DocumentIssueKind.deadlinePassed)));
      return;
    }
    emit(state.copyWith(uploading: true, progress: 0, clearIssue: true));
    // Registered for as long as the upload runs, even if the screen is left.
    final done = _pending?.begin(requestId: request.requestId, referenceId: request.referenceId);
    final Either<Failure, void> result;
    try {
      result = await _upload(
        requestId: request.requestId,
        document: doc,
        onProgress: (f) {
          if (!isClosed) add(_ProgressChanged(f));
        },
      );
    } finally {
      done?.call();
    }
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(uploading: false, issue: DocumentIssue.fromUpload(failure))),
      (_) => emit(state.copyWith(uploading: false, progress: 1, submitted: true)),
    );
  }
}
