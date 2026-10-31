import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';

/// A report to run: the report definition the server understands ([spec], passed through as it
/// is) and a title for the screen. The app does not look inside [spec]: the contract does not
/// publish its structure (DECISIONS Q34), so whoever builds it owns that knowledge.
class ReportRequest extends Equatable {
  const ReportRequest({required this.spec, required this.title, this.subtitle});

  final Map<String, dynamic> spec;
  final String title;

  /// For example the period the report covers.
  final String? subtitle;

  @override
  List<Object?> get props => [spec, title, subtitle];
}

enum ReportColumnKind { text, number, money, date, other }

class ReportColumnInfo extends Equatable {
  const ReportColumnInfo({required this.key, required this.label, required this.kind});

  final String key;
  final String label;
  final ReportColumnKind kind;

  bool get isNumeric => kind == ReportColumnKind.number || kind == ReportColumnKind.money;

  @override
  List<Object?> get props => [key, label, kind];
}

/// A report result as the server answers (`ReportResult`): [rows] and [totals] are text by column.
class ReportData extends Equatable {
  const ReportData({required this.columns, required this.rows, required this.totals, required this.totalRows, required this.truncated});

  final List<ReportColumnInfo> columns;

  /// One list per row, one string per column (same order as [columns]).
  final List<List<String>> rows;

  /// One string per column; null when the report has no totals.
  final List<String>? totals;

  /// How many rows the whole report has (the answer may hold fewer).
  final int totalRows;

  /// The server cut the answer short.
  final bool truncated;

  @override
  List<Object?> get props => [columns, rows, totals, totalRows, truncated];
}

enum ReportFormat {
  pdf('pdf'),
  xlsx('xlsx'),
  csv('csv');

  const ReportFormat(this.value);
  final String value;
}

/// An exported file: its name and content, held in memory only.
class ReportFile extends Equatable {
  const ReportFile({required this.filename, required this.bytes, required this.rowCount});

  final String filename;
  final Uint8List bytes;
  final int rowCount;

  @override
  List<Object?> get props => [filename, bytes.length, rowCount];
}

enum ReportIssueKind { forbidden, specInvalid, tooLarge, notFound, offline, generic }

class ReportIssue extends Equatable {
  const ReportIssue(this.kind);

  final ReportIssueKind kind;

  /// Codes of the contract (reference, "Error codes").
  static const specInvalidCode = 'report_spec_invalid';
  static const tooLargeCode = 'report_too_large';
  static const notFoundCode = 'report_not_found';

  factory ReportIssue.from(Failure failure) {
    if (failure is NetworkFailure) {
      return const ReportIssue(ReportIssueKind.offline);
    }
    if (failure is ForbiddenFailure || (failure is ServerFailure && failure.code == 'permission_denied')) {
      return const ReportIssue(ReportIssueKind.forbidden);
    }
    if (failure is ServerFailure) {
      return switch (failure.code) {
        specInvalidCode => const ReportIssue(ReportIssueKind.specInvalid),
        tooLargeCode => const ReportIssue(ReportIssueKind.tooLarge),
        notFoundCode => const ReportIssue(ReportIssueKind.notFound),
        _ => const ReportIssue(ReportIssueKind.generic),
      };
    }
    return const ReportIssue(ReportIssueKind.generic);
  }

  @override
  List<Object?> get props => [kind];
}
