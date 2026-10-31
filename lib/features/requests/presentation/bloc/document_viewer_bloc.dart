import 'dart:typed_data';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/request_document_usecases.dart';

sealed class DocumentViewerEvent extends Equatable {
  const DocumentViewerEvent();

  @override
  List<Object?> get props => [];
}

final class DocumentViewerLoadRequested extends DocumentViewerEvent {
  const DocumentViewerLoadRequested(this.url);

  final String url;

  @override
  List<Object?> get props => [url];
}

/// Opens a stored file (a request's output) by id; a fresh signed link is
/// requested each time, so a retry always works with a live link.
final class DocumentViewerFileRequested extends DocumentViewerEvent {
  const DocumentViewerFileRequested(this.fileId);

  final String fileId;

  @override
  List<Object?> get props => [fileId];
}

final class DocumentViewerSaveRequested extends DocumentViewerEvent {
  const DocumentViewerSaveRequested(this.fileName);

  final String fileName;

  @override
  List<Object?> get props => [fileName];
}

final class DocumentViewerShareRequested extends DocumentViewerEvent {
  const DocumentViewerShareRequested(this.fileName);

  final String fileName;

  @override
  List<Object?> get props => [fileName];
}

enum DocumentViewerStatus { loading, ready, failed }

enum DocumentExportOutcome { saved, saveFailed, shareFailed }

class DocumentViewerState extends Equatable {
  const DocumentViewerState({
    this.status = DocumentViewerStatus.loading,
    this.bytes,
    this.exporting = false,
    this.outcome,
    this.outcomeSeq = 0,
  });

  final DocumentViewerStatus status;
  final Uint8List? bytes;
  final bool exporting;

  /// The last save / share result; [outcomeSeq] changes on every one so the
  /// screen can show a message even when two in a row are equal.
  final DocumentExportOutcome? outcome;
  final int outcomeSeq;

  DocumentViewerState copyWith({bool? exporting, DocumentExportOutcome? outcome}) => DocumentViewerState(
        status: status,
        bytes: bytes,
        exporting: exporting ?? this.exporting,
        outcome: outcome ?? this.outcome,
        outcomeSeq: outcome != null ? outcomeSeq + 1 : outcomeSeq,
      );

  @override
  List<Object?> get props => [status, bytes?.length, exporting, outcome, outcomeSeq];
}

class DocumentViewerBloc extends Bloc<DocumentViewerEvent, DocumentViewerState> {
  DocumentViewerBloc({
    required FetchDocumentFileUseCase fetchDocument,
    required FetchRequestFileUseCase fetchFile,
    required SaveDocumentUseCase saveDocument,
    required ShareDocumentUseCase shareDocument,
  })  : _fetch = fetchDocument,
        _fetchFile = fetchFile,
        _save = saveDocument,
        _share = shareDocument,
        super(const DocumentViewerState()) {
    on<DocumentViewerLoadRequested>(_onLoad, transformer: restartable());
    on<DocumentViewerFileRequested>(_onFile, transformer: restartable());
    on<DocumentViewerSaveRequested>(_onSave, transformer: droppable());
    on<DocumentViewerShareRequested>(_onShare, transformer: droppable());
  }

  final FetchDocumentFileUseCase _fetch;
  final FetchRequestFileUseCase _fetchFile;
  final SaveDocumentUseCase _save;
  final ShareDocumentUseCase _share;

  Future<void> _onLoad(DocumentViewerLoadRequested event, Emitter<DocumentViewerState> emit) async {
    emit(const DocumentViewerState());
    final result = await _fetch(event.url);
    result.match(
      (failure) => emit(const DocumentViewerState(status: DocumentViewerStatus.failed)),
      (bytes) => emit(DocumentViewerState(status: DocumentViewerStatus.ready, bytes: bytes)),
    );
  }

  Future<void> _onFile(DocumentViewerFileRequested event, Emitter<DocumentViewerState> emit) async {
    emit(const DocumentViewerState());
    final result = await _fetchFile(event.fileId);
    result.match(
      (failure) => emit(const DocumentViewerState(status: DocumentViewerStatus.failed)),
      (bytes) => emit(DocumentViewerState(status: DocumentViewerStatus.ready, bytes: bytes)),
    );
  }

  Future<void> _onSave(DocumentViewerSaveRequested event, Emitter<DocumentViewerState> emit) async {
    final bytes = state.bytes;
    if (bytes == null) return;
    emit(state.copyWith(exporting: true));
    final result = await _save(event.fileName, bytes);
    result.match(
      (failure) => emit(state.copyWith(exporting: false, outcome: DocumentExportOutcome.saveFailed)),
      // Cancelled by the user: no message.
      (saved) => emit(
        saved
            ? state.copyWith(exporting: false, outcome: DocumentExportOutcome.saved)
            : state.copyWith(exporting: false),
      ),
    );
  }

  Future<void> _onShare(DocumentViewerShareRequested event, Emitter<DocumentViewerState> emit) async {
    final bytes = state.bytes;
    if (bytes == null) return;
    emit(state.copyWith(exporting: true));
    final result = await _share(event.fileName, bytes);
    result.match(
      (failure) => emit(state.copyWith(exporting: false, outcome: DocumentExportOutcome.shareFailed)),
      (_) => emit(state.copyWith(exporting: false)),
    );
  }
}
