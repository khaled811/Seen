// The manifest being built (Figma REQ-14): the list, import, add a traveler, save as a draft
// and send. One action runs at a time (`busy`), so a double tap never sends twice.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/unsupported.dart';
import '../../domain/entities/manifest.dart';
import '../../domain/repositories/manifest_repository.dart';

enum ManifestLoad { loading, loaded, failure }

enum ManifestNotice {
  saved,
  added,
  imported,
  importTooLarge,
  importFailed,
  failed
}

/// The rows shown before "+ N more".
const manifestPreviewRows = 5;

class ManifestBuildState extends Equatable {
  const ManifestBuildState({
    this.load = ManifestLoad.loading,
    this.draft,
    this.showAll = false,
    this.busy = false,
    this.notice,
    this.noticeSeq = 0,
    this.submittedId,
    this.unsupported = false,
  });

  final ManifestLoad load;

  /// The load failed because the API has no group manifest: nothing to retry.
  final bool unsupported;
  final ManifestDraft? draft;
  final bool showAll;
  final bool busy;
  final ManifestNotice? notice;
  final int noticeSeq;

  /// Set once the manifest is sent: the screen moves on to its summary.
  final String? submittedId;

  /// How many rows the list shows now.
  int get visibleCount {
    final n = draft?.travelers.length ?? 0;
    return showAll || n <= manifestPreviewRows ? n : manifestPreviewRows;
  }

  int get hiddenCount => (draft?.travelers.length ?? 0) - visibleCount;

  ManifestBuildState copyWith({
    ManifestLoad? load,
    ManifestDraft? draft,
    bool? showAll,
    bool? busy,
    ManifestNotice? notice,
    String? submittedId,
  }) =>
      ManifestBuildState(
        load: load ?? this.load,
        draft: draft ?? this.draft,
        showAll: showAll ?? this.showAll,
        busy: busy ?? this.busy,
        notice: notice ?? this.notice,
        noticeSeq: notice == null ? noticeSeq : noticeSeq + 1,
        submittedId: submittedId ?? this.submittedId,
        unsupported: unsupported,
      );

  @override
  List<Object?> get props =>
      [load, draft, showAll, busy, notice, noticeSeq, submittedId, unsupported];
}

class ManifestBuildCubit extends Cubit<ManifestBuildState> {
  ManifestBuildCubit(this._repository, this._picker,
      {required this.serviceId, required this.serviceLabel})
      : super(const ManifestBuildState());

  final ManifestRepository _repository;
  final ManifestImportPicker _picker;
  final String serviceId;
  final String serviceLabel;

  Future<void> load() async {
    emit(const ManifestBuildState());
    final r = await _repository.openDraft(
        serviceId: serviceId, serviceLabel: serviceLabel);
    if (isClosed) return;
    r.fold(
      (f) => emit(ManifestBuildState(load: ManifestLoad.failure, unsupported: isUnsupportedFailure(f))),
      (d) => emit(ManifestBuildState(load: ManifestLoad.loaded, draft: d)),
    );
  }

  void toggleShowAll() => emit(state.copyWith(showAll: !state.showAll));

  bool get _canAct => state.draft != null && !state.busy;

  Future<void> addTraveler(
      {required String name, String? passportNumber}) async {
    if (!_canAct) return;
    emit(state.copyWith(busy: true));
    final r = await _repository.addTraveler(
        draftId: state.draft!.id, name: name, passportNumber: passportNumber);
    if (isClosed) return;
    r.fold(
      (_) => emit(state.copyWith(busy: false, notice: ManifestNotice.failed)),
      // The new line is at the bottom: show the whole list so it can be seen.
      (d) => emit(state.copyWith(
          busy: false, draft: d, showAll: true, notice: ManifestNotice.added)),
    );
  }

  Future<void> import() async {
    if (!_canAct) return;
    emit(state.copyWith(busy: true));
    final picked = await _picker.pick();
    if (isClosed) return;
    final failure = picked.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      final tooLarge = failure is ServerFailure &&
          failure.code == manifestImportTooLargeCode;
      emit(state.copyWith(
          busy: false,
          notice: tooLarge
              ? ManifestNotice.importTooLarge
              : ManifestNotice.importFailed));
      return;
    }
    final file = picked.fold<ManifestImportFile?>((_) => null, (f) => f);
    if (file == null) {
      emit(state.copyWith(busy: false)); // Cancelled.
      return;
    }
    if (file.bytes.length > manifestImportMaxBytes) {
      emit(state.copyWith(busy: false, notice: ManifestNotice.importTooLarge));
      return;
    }
    final r =
        await _repository.importList(draftId: state.draft!.id, file: file);
    if (isClosed) return;
    r.fold(
      (_) => emit(
          state.copyWith(busy: false, notice: ManifestNotice.importFailed)),
      (d) => emit(state.copyWith(
          busy: false,
          draft: d,
          showAll: true,
          notice: ManifestNotice.imported)),
    );
  }

  Future<void> saveDraft() async {
    if (!_canAct) return;
    emit(state.copyWith(busy: true));
    final r = await _repository.saveDraft(state.draft!.id);
    if (isClosed) return;
    emit(state.copyWith(
        busy: false,
        notice: r.isRight() ? ManifestNotice.saved : ManifestNotice.failed));
  }

  Future<void> submit() async {
    if (!_canAct) return;
    emit(state.copyWith(busy: true));
    final r = await _repository.submit(state.draft!.id);
    if (isClosed) return;
    r.fold(
      (_) => emit(state.copyWith(busy: false, notice: ManifestNotice.failed)),
      (id) => emit(state.copyWith(busy: false, submittedId: id)),
    );
  }
}
