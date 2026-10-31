import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/reports_repository.dart';

/// `runAgentReport(spec, language)` and `exportAgentReport(spec, format, language)`.
///
/// The `spec` goes to the server untouched. The answer's `rows` and `totals` are JSON whose layout
/// the contract does not fix, so they are read for both an object per row (by column key) and a
/// list per row (by position); anything else becomes empty cells, never an error.
class ReportsRemoteDataSource implements ReportsRepository {
  ReportsRemoteDataSource({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQL = graphQLService,
        _language = language;

  final GraphQLService _graphQL;
  final AppLanguage _language;

  static final _runDoc = gql(r'''
    query RunAgentReport($spec: JSON!, $language: String!) {
      runAgentReport(spec: $spec, language: $language) {
        columns { key labelEn labelAr kind }
        rows
        totals
        totalRows
        truncated
      }
    }
  ''');

  static final _exportDoc = gql(r'''
    query ExportAgentReport($spec: JSON!, $format: String!, $language: String!) {
      exportAgentReport(spec: $spec, format: $format, language: $language) {
        filename
        contentType
        contentBase64
        rowCount
      }
    }
  ''');

  String get _lang => _language.code == 'en' ? 'en' : 'ar';

  static ReportColumnKind _kind(String? value) => switch (value) {
        'text' || 'string' => ReportColumnKind.text,
        'number' || 'int' || 'integer' || 'count' => ReportColumnKind.number,
        'money' || 'amount' || 'decimal' || 'currency' => ReportColumnKind.money,
        'date' || 'datetime' => ReportColumnKind.date,
        _ => ReportColumnKind.other,
      };

  static String _cell(Object? value) => value == null ? '' : '$value';

  static List<String> _row(Object? raw, List<ReportColumnInfo> columns) {
    if (raw is Map) {
      return [for (final c in columns) _cell(raw[c.key])];
    }
    if (raw is List) {
      return [for (var i = 0; i < columns.length; i++) i < raw.length ? _cell(raw[i]) : ''];
    }
    return [for (final _ in columns) ''];
  }

  @override
  Future<Either<Failure, ReportData>> run(ReportRequest request) => _graphQL.query<ReportData>(QueryOptions<ReportData>(
        document: _runDoc,
        variables: {'spec': request.spec, 'language': _lang},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) {
          final r = j['runAgentReport'] as Map<String, dynamic>;
          final columns = [
            for (final c in (r['columns'] as List<dynamic>).cast<Map<String, dynamic>>())
              ReportColumnInfo(
                key: c['key'] as String,
                label: _language.pick(ar: c['labelAr'] as String?, en: c['labelEn'] as String?),
                kind: _kind(c['kind'] as String?),
              ),
          ];
          final totals = r['totals'];
          return ReportData(
            columns: columns,
            rows: [for (final row in (r['rows'] as List<dynamic>? ?? const [])) _row(row, columns)],
            totals: totals == null ? null : _row(totals, columns),
            totalRows: (r['totalRows'] as num?)?.toInt() ?? 0,
            truncated: r['truncated'] == true,
          );
        },
      ));

  @override
  Future<Either<Failure, ReportFile>> export(ReportRequest request, ReportFormat format) => _graphQL.query<ReportFile>(QueryOptions<ReportFile>(
        document: _exportDoc,
        variables: {'spec': request.spec, 'format': format.value, 'language': _lang},
        fetchPolicy: FetchPolicy.noCache,
        parserFn: (j) {
          final r = j['exportAgentReport'] as Map<String, dynamic>;
          return ReportFile(
            filename: r['filename'] as String,
            bytes: base64Decode(r['contentBase64'] as String),
            rowCount: (r['rowCount'] as num?)?.toInt() ?? 0,
          );
        },
      ));
}
