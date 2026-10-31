// Running a report and exporting it (design/gaps REP-03..05). The result and the exported file
// live in these states only, in memory; nothing is cached or written except what the person
// saves or shares.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../requests/domain/services/document_exporter.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/reports_repository.dart';

// ───────────────────────── result ─────────────────────────

class ReportResultState extends Equatable {
  const ReportResultState({this.loading = true, this.data, this.issue});

  final bool loading;
  final ReportData? data;
  final ReportIssue? issue;

  /// The server holds more rows than the answer carries (or refused for size).
  bool get truncated => (data?.truncated ?? false) || (data != null && data!.totalRows > data!.rows.length) || issue?.kind == ReportIssueKind.tooLarge;

  @override
  List<Object?> get props => [loading, data, issue];
}

class ReportResultCubit extends Cubit<ReportResultState> {
  ReportResultCubit(this._repository, this.request) : super(const ReportResultState());

  final ReportsRepository _repository;
  final ReportRequest request;

  /// Runs the report. A second call while one is running is ignored.
  Future<void> load() async {
    if (state.loading && state.data != null) {
      return;
    }
    emit(const ReportResultState());
    final result = await _repository.run(request);
    if (isClosed) {
      return;
    }
    result.fold(
      (failure) => emit(ReportResultState(loading: false, issue: ReportIssue.from(failure))),
      (data) => emit(ReportResultState(loading: false, data: data)),
    );
  }
}

// ───────────────────────── export ─────────────────────────

enum ReportExportStatus { idle, exporting, ready, failed }

/// What happened to the file the person saved or shared.
enum ReportExportOutcome { saved, saveFailed, shareFailed }

class ReportExportState extends Equatable {
  const ReportExportState({this.format = ReportFormat.xlsx, this.status = ReportExportStatus.idle, this.file, this.issue, this.outcome, this.outcomeSeq = 0});

  final ReportFormat format;
  final ReportExportStatus status;
  final ReportFile? file;
  final ReportIssue? issue;
  final ReportExportOutcome? outcome;

  /// Changes with every outcome so the sheet shows one message per attempt.
  final int outcomeSeq;

  ReportExportState copyWith({
    ReportFormat? format,
    ReportExportStatus? status,
    ReportFile? file,
    bool clearFile = false,
    ReportIssue? issue,
    bool clearIssue = false,
    ReportExportOutcome? outcome,
    int? outcomeSeq,
  }) =>
      ReportExportState(
        format: format ?? this.format,
        status: status ?? this.status,
        file: clearFile ? null : (file ?? this.file),
        issue: clearIssue ? null : (issue ?? this.issue),
        outcome: outcome ?? this.outcome,
        outcomeSeq: outcomeSeq ?? this.outcomeSeq,
      );

  @override
  List<Object?> get props => [format, status, file, issue, outcome, outcomeSeq];
}

class ReportExportCubit extends Cubit<ReportExportState> {
  ReportExportCubit(this._repository, this._exporter, this.request) : super(const ReportExportState());

  final ReportsRepository _repository;
  final DocumentExporter _exporter;
  final ReportRequest request;

  void selectFormat(ReportFormat format) {
    if (state.status == ReportExportStatus.exporting) {
      return;
    }
    emit(state.copyWith(format: format, status: ReportExportStatus.idle, clearFile: true, clearIssue: true));
  }

  /// One export at a time: a second tap while one runs is ignored.
  Future<void> export() async {
    if (state.status == ReportExportStatus.exporting) {
      return;
    }
    emit(state.copyWith(status: ReportExportStatus.exporting, clearIssue: true, clearFile: true));
    final result = await _repository.export(request, state.format);
    if (isClosed) {
      return;
    }
    result.fold(
      (failure) => emit(state.copyWith(status: ReportExportStatus.failed, issue: ReportIssue.from(failure))),
      (file) => emit(state.copyWith(status: ReportExportStatus.ready, file: file)),
    );
  }

  Future<void> download() async {
    final file = state.file;
    if (file == null) {
      return;
    }
    final result = await _exporter.save(file.filename, file.bytes);
    if (isClosed) {
      return;
    }
    result.fold(
      (_) => emit(state.copyWith(outcome: ReportExportOutcome.saveFailed, outcomeSeq: state.outcomeSeq + 1)),
      (saved) => saved ? emit(state.copyWith(outcome: ReportExportOutcome.saved, outcomeSeq: state.outcomeSeq + 1)) : null,
    );
  }

  Future<void> share() async {
    final file = state.file;
    if (file == null) {
      return;
    }
    final result = await _exporter.share(file.filename, file.bytes);
    if (isClosed) {
      return;
    }
    result.fold((_) => emit(state.copyWith(outcome: ReportExportOutcome.shareFailed, outcomeSeq: state.outcomeSeq + 1)), (_) {});
  }
}
