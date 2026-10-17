import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/booking_draft.dart';
import '../../domain/usecases/booking_draft_usecases.dart';

sealed class DraftsEvent extends Equatable {
  const DraftsEvent();

  @override
  List<Object?> get props => [];
}

final class DraftsLoadRequested extends DraftsEvent {
  const DraftsLoadRequested();
}

final class DraftDeleteRequested extends DraftsEvent {
  const DraftDeleteRequested(this.draft);

  final BookingDraft draft;

  @override
  List<Object?> get props => [draft];
}

/// "Undo" on the deleted toast: puts the last deleted draft back.
final class DraftDeleteUndone extends DraftsEvent {
  const DraftDeleteUndone();
}

enum DraftsStatus { loading, ready, failed }

class DraftsState extends Equatable {
  const DraftsState({
    this.status = DraftsStatus.loading,
    this.drafts = const [],
    this.lastDeleted,
    this.deleteSeq = 0,
  });

  final DraftsStatus status;
  final List<BookingDraft> drafts;

  /// The draft just deleted, kept for "Undo"; [deleteSeq] changes per delete so
  /// the screen shows one toast each time.
  final BookingDraft? lastDeleted;
  final int deleteSeq;

  DraftsState copyWith({
    DraftsStatus? status,
    List<BookingDraft>? drafts,
    BookingDraft? lastDeleted,
    bool clearLastDeleted = false,
    int? deleteSeq,
  }) =>
      DraftsState(
        status: status ?? this.status,
        drafts: drafts ?? this.drafts,
        lastDeleted: clearLastDeleted ? null : (lastDeleted ?? this.lastDeleted),
        deleteSeq: deleteSeq ?? this.deleteSeq,
      );

  @override
  List<Object?> get props => [status, drafts, lastDeleted, deleteSeq];
}

class DraftsBloc extends Bloc<DraftsEvent, DraftsState> {
  DraftsBloc({
    required GetBookingDraftsUseCase getDrafts,
    required DeleteBookingDraftUseCase deleteDraft,
    required SaveBookingDraftUseCase saveDraft,
  })  : _get = getDrafts,
        _delete = deleteDraft,
        _save = saveDraft,
        super(const DraftsState()) {
    on<DraftsLoadRequested>(_onLoad, transformer: restartable());
    on<DraftDeleteRequested>(_onDelete, transformer: sequential());
    on<DraftDeleteUndone>(_onUndo, transformer: droppable());
  }

  final GetBookingDraftsUseCase _get;
  final DeleteBookingDraftUseCase _delete;
  final SaveBookingDraftUseCase _save;

  Future<void> _onLoad(DraftsLoadRequested event, Emitter<DraftsState> emit) async {
    final result = await _get();
    result.match(
      (failure) => emit(state.copyWith(status: DraftsStatus.failed)),
      (drafts) => emit(state.copyWith(status: DraftsStatus.ready, drafts: drafts)),
    );
  }

  Future<void> _onDelete(DraftDeleteRequested event, Emitter<DraftsState> emit) async {
    final result = await _delete(event.draft.id);
    if (result.isLeft()) return;
    emit(state.copyWith(
      drafts: state.drafts.where((d) => d.id != event.draft.id).toList(),
      lastDeleted: event.draft,
      deleteSeq: state.deleteSeq + 1,
    ));
  }

  Future<void> _onUndo(DraftDeleteUndone event, Emitter<DraftsState> emit) async {
    final draft = state.lastDeleted;
    if (draft == null) return;
    // Same id and edit time: it comes back exactly as it was.
    final result = await _save(draft);
    if (result.isLeft()) return;
    final drafts = [...state.drafts, draft]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    emit(state.copyWith(drafts: drafts, clearLastDeleted: true));
  }
}
