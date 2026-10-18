// A sent manifest with a status per traveler (Figma REQ-14b): re-send a rejected traveler and
// download the issued visas. One action at a time.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/manifest.dart';
import '../../domain/repositories/manifest_repository.dart';
import 'manifest_build_cubit.dart' show ManifestLoad;

enum ManifestSummaryNotice { resubmitted, downloadFailed, failed }

/// Opens a link outside the app; false = nothing could open it.
typedef UrlOpener = Future<bool> Function(String url);

class ManifestSummaryState extends Equatable {
  const ManifestSummaryState({
    this.load = ManifestLoad.loading,
    this.summary,
    this.busyTravelerId,
    this.downloading = false,
    this.notice,
    this.noticeSeq = 0,
  });

  final ManifestLoad load;
  final ManifestSummary? summary;

  /// The rejected traveler being sent again.
  final String? busyTravelerId;
  final bool downloading;
  final ManifestSummaryNotice? notice;
  final int noticeSeq;

  bool get busy => busyTravelerId != null || downloading;

  ManifestSummaryState copyWith({
    ManifestLoad? load,
    ManifestSummary? summary,
    String? busyTravelerId,
    bool clearBusyTraveler = false,
    bool? downloading,
    ManifestSummaryNotice? notice,
  }) =>
      ManifestSummaryState(
        load: load ?? this.load,
        summary: summary ?? this.summary,
        busyTravelerId:
            clearBusyTraveler ? null : (busyTravelerId ?? this.busyTravelerId),
        downloading: downloading ?? this.downloading,
        notice: notice ?? this.notice,
        noticeSeq: notice == null ? noticeSeq : noticeSeq + 1,
      );

  @override
  List<Object?> get props =>
      [load, summary, busyTravelerId, downloading, notice, noticeSeq];
}

class ManifestSummaryCubit extends Cubit<ManifestSummaryState> {
  ManifestSummaryCubit(this._repository, this._openUrl,
      {required this.manifestId})
      : super(const ManifestSummaryState());

  final ManifestRepository _repository;
  final UrlOpener _openUrl;
  final String manifestId;

  Future<void> load() async {
    emit(const ManifestSummaryState());
    final r = await _repository.summary(manifestId);
    if (isClosed) return;
    r.fold(
      (_) => emit(const ManifestSummaryState(load: ManifestLoad.failure)),
      (s) => emit(ManifestSummaryState(load: ManifestLoad.loaded, summary: s)),
    );
  }

  Future<void> resubmit(String travelerId) async {
    if (state.busy || state.summary == null) return;
    emit(state.copyWith(busyTravelerId: travelerId));
    final r = await _repository.resubmit(
        manifestId: manifestId, travelerId: travelerId);
    if (isClosed) return;
    r.fold(
      (_) => emit(state.copyWith(
          clearBusyTraveler: true, notice: ManifestSummaryNotice.failed)),
      (s) => emit(state.copyWith(
          clearBusyTraveler: true,
          summary: s,
          notice: ManifestSummaryNotice.resubmitted)),
    );
  }

  Future<void> downloadIssued() async {
    if (state.busy || state.summary == null) return;
    emit(state.copyWith(downloading: true));
    final r = await _repository.issuedVisasUrl(manifestId);
    if (isClosed) return;
    final url = r.fold<String?>((_) => null, (u) => u);
    // Only a secure link is opened outside the app.
    final opened = url != null &&
        Uri.tryParse(url)?.scheme == 'https' &&
        await _openUrl(url);
    if (isClosed) return;
    emit(state.copyWith(
        downloading: false,
        notice: opened ? null : ManifestSummaryNotice.downloadFailed));
  }
}
