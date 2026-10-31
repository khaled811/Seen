import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../requests/domain/usecases/request_document_usecases.dart';
import '../../domain/entities/statement.dart';
import '../../domain/usecases/export_statement_usecase.dart';

enum StatementPeriod { thisMonth, threeMonths, custom }

enum StatementAction { download, share }

enum StatementStatus { idle, generating, failed }

/// What the sheet tells the agent once a download / share finished.
enum StatementOutcome { saved, saveFailed, shareFailed }

class StatementExportState extends Equatable {
  const StatementExportState({this.status = StatementStatus.idle, this.outcome, this.outcomeSeq = 0});

  final StatementStatus status;
  final StatementOutcome? outcome;

  /// Changes on every outcome so the sheet shows one message per attempt.
  final int outcomeSeq;

  @override
  List<Object?> get props => [status, outcome, outcomeSeq];
}

/// The days a statement covers.
class StatementRange {
  const StatementRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  /// "This month" runs from the 1st to today; "3 months" from the same day three
  /// months back to today.
  factory StatementRange.forPeriod(StatementPeriod period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      StatementPeriod.thisMonth => StatementRange(DateTime(now.year, now.month), today),
      StatementPeriod.threeMonths => StatementRange(DateTime(now.year, now.month - 3, now.day), today),
      StatementPeriod.custom => StatementRange(today, today),
    };
  }
}

/// Builds an account statement and saves or shares it (Figma WAL-06). One export
/// at a time: a second tap while one is running is ignored.
class StatementExportCubit extends Cubit<StatementExportState> {
  StatementExportCubit({
    required ExportStatementUseCase exportStatement,
    required SaveDocumentUseCase saveDocument,
    required ShareDocumentUseCase shareDocument,
  })  : _export = exportStatement,
        _save = saveDocument,
        _share = shareDocument,
        super(const StatementExportState());

  final ExportStatementUseCase _export;
  final SaveDocumentUseCase _save;
  final ShareDocumentUseCase _share;

  Future<void> export({
    required StatementRange range,
    required StatementFormat format,
    required StatementAction action,
  }) async {
    if (state.status == StatementStatus.generating) return;
    emit(StatementExportState(status: StatementStatus.generating, outcomeSeq: state.outcomeSeq));

    final file = await _export(from: range.from, to: range.to, format: format);
    if (isClosed) return;
    final built = file.toNullable();
    if (built == null) return _fail();

    final bytes = built.bytes;

    switch (action) {
      case StatementAction.download:
        final saved = await _save(built.fileName, bytes);
        if (isClosed) return;
        saved.match(
          (_) => _done(StatementOutcome.saveFailed),
          // `false` = the agent cancelled the save dialog: no message.
          (ok) => ok ? _done(StatementOutcome.saved) : _done(null),
        );
      case StatementAction.share:
        final shared = await _share(built.fileName, bytes);
        if (isClosed) return;
        shared.match((_) => _done(StatementOutcome.shareFailed), (_) => _done(null));
    }
  }

  void _fail() => emit(StatementExportState(status: StatementStatus.failed, outcomeSeq: state.outcomeSeq));

  void _done(StatementOutcome? outcome) => emit(
        StatementExportState(
          outcome: outcome,
          outcomeSeq: outcome == null ? state.outcomeSeq : state.outcomeSeq + 1,
        ),
      );
}
