// Reports (design/gaps REP): the table, the data source against the contract, the cubits, the
// result screen in each state and the export sheet. Arabic / RTL, 390 wide.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/core/presentation/widgets/report_table.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/utils/latin_digits.dart';
import 'package:seen_booking/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:seen_booking/features/reports/domain/entities/report.dart';
import 'package:seen_booking/features/reports/domain/repositories/reports_repository.dart';
import 'package:seen_booking/features/reports/presentation/bloc/report_cubits.dart';
import 'package:seen_booking/features/reports/presentation/screens/report_result_screen.dart';
import 'package:seen_booking/features/requests/domain/services/document_exporter.dart';

import '../../support/scripted_graphql_service.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

const _request = ReportRequest(spec: {'source': 'requests'}, title: 'تقرير الحجوزات', subtitle: '١–٣٠ سبتمبر');

const _columns = [
  ReportColumnInfo(key: 'ref', label: 'رقم الطلب', kind: ReportColumnKind.text),
  ReportColumnInfo(key: 'traveler', label: 'المسافر', kind: ReportColumnKind.text),
  ReportColumnInfo(key: 'amount', label: 'المبلغ', kind: ReportColumnKind.money),
];

ReportData _data({bool truncated = false, int? totalRows}) => ReportData(
      columns: _columns,
      rows: const [
        ['SB-1001', 'أمل صالح', '85.00'],
        ['SB-1002', 'خالد علي', '170.00'],
      ],
      totals: const ['', '', '255.00'],
      totalRows: totalRows ?? 2,
      truncated: truncated,
    );

class _Repo implements ReportsRepository {
  Either<Failure, ReportData> runResult = Right(_data());
  Either<Failure, ReportFile> exportResult = Right(ReportFile(filename: 'bookings-2026-09.xlsx', bytes: Uint8List.fromList(List.filled(2048, 1)), rowCount: 2));
  Completer<void>? holdRun;
  Completer<void>? holdExport;
  int runs = 0;
  final exported = <ReportFormat>[];

  @override
  Future<Either<Failure, ReportData>> run(ReportRequest request) async {
    runs++;
    await holdRun?.future;
    return runResult;
  }

  @override
  Future<Either<Failure, ReportFile>> export(ReportRequest request, ReportFormat format) async {
    exported.add(format);
    await holdExport?.future;
    return exportResult;
  }
}

class _Exporter implements DocumentExporter {
  final saved = <String>[];
  final shared = <String>[];
  Either<Failure, bool> saveResult = const Right(true);
  Either<Failure, bool> shareResult = const Right(true);

  @override
  Future<Either<Failure, bool>> save(String fileName, Uint8List bytes) async {
    saved.add(fileName);
    return saveResult;
  }

  @override
  Future<Either<Failure, bool>> share(String fileName, Uint8List bytes) async {
    shared.add(fileName);
    return shareResult;
  }
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: home,
    );

Future<void> _open(WidgetTester tester, _Repo repo, _Exporter exporter) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(ReportResultScreen(
    request: _request,
    createCubit: () => ReportResultCubit(repo, _request),
    createExport: () => ReportExportCubit(repo, exporter, _request),
  )));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => InjectionContainer.instance.init());

  group('ReportTable', () {
    const columns = [
      ReportTableColumn('رقم الطلب', width: 104, ltr: true),
      ReportTableColumn('المسافر', width: 120),
      ReportTableColumn('الخدمة', width: 116),
      ReportTableColumn('الحالة', width: 84),
      ReportTableColumn('المبلغ', width: 110, numeric: true),
    ];
    final rows = [
      for (var i = 0; i < 3; i++) ['SB-100$i', 'مسافر $i', 'تأشيرة', 'مكتمل', '${85 * (i + 1)}.00'],
    ];

    Future<void> pump(WidgetTester tester, {double width = 390, List<String>? totals}) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: ReportTable(columns: columns, rows: rows, totals: totals)))));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the first column stays put while the others scroll sideways', (tester) async {
      await pump(tester, totals: const ['', '', '', '', '510.00']);
      final before = tester.getTopLeft(find.text('SB-1000')).dx;
      final amountBefore = tester.getTopLeft(find.text('85.00')).dx;
      // In RTL the columns start at the right edge: the rest is revealed by dragging to the right.
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(200, 0));
      await tester.pump();
      expect(tester.getTopLeft(find.text('SB-1000')).dx, before, reason: 'the sticky column does not move');
      expect(tester.getTopLeft(find.text('85.00')).dx, isNot(amountBefore), reason: 'the others do');
    });

    testWidgets('the totals row is last and a table without totals has none', (tester) async {
      await pump(tester, totals: const ['', '', '', '', '510.00']);
      final totalY = tester.getTopLeft(find.text('510.00')).dy;
      final lastRowY = tester.getTopLeft(find.text('SB-1002')).dy;
      expect(totalY > lastRowY, isTrue);
      await pump(tester);
      expect(find.text('510.00'), findsNothing);
    });

    testWidgets('numbers and codes read left to right; rows are a fixed 44 high', (tester) async {
      await pump(tester);
      expect(tester.widget<Text>(find.text('85.00')).textDirection, TextDirection.ltr);
      expect(tester.widget<Text>(find.text('SB-1000')).textDirection, TextDirection.ltr);
      expect(tester.widget<Text>(find.text('مسافر 0')).textDirection, isNull);
      final heights = {for (final f in ['SB-1000', 'SB-1001']) tester.getTopLeft(find.text(f)).dy};
      expect((heights.last - heights.first).abs(), 44);
    });
  });

  group('data source', () {
    ReportsRemoteDataSource source(ScriptedGraphQLService graphql, {String language = 'en'}) =>
        ReportsRemoteDataSource(graphQLService: graphql, language: AppLanguage(language));

    test('runs the report with the spec untouched and reads rows given as objects or as lists', () async {
      final graphql = ScriptedGraphQLService({
        'RunAgentReport': {
          'runAgentReport': {
            'columns': [
              {'key': 'ref', 'labelEn': 'Request', 'labelAr': 'الطلب', 'kind': 'text'},
              {'key': 'amount', 'labelEn': 'Amount', 'labelAr': 'المبلغ', 'kind': 'money'},
            ],
            'rows': [
              {'ref': 'SB-1', 'amount': '85.00'},
              ['SB-2', 170],
              'junk',
            ],
            'totals': {'amount': '255.00'},
            'totalRows': 3,
            'truncated': false,
          },
        },
      });
      final data = ((await source(graphql).run(const ReportRequest(spec: {'source': 'requests', 'x': 1}, title: 't'))) as Right).value as ReportData;
      expect(data.columns.map((c) => (c.label, c.kind)), [('Request', ReportColumnKind.text), ('Amount', ReportColumnKind.money)]);
      expect(data.rows, [
        ['SB-1', '85.00'],
        ['SB-2', '170'],
        ['', ''],
      ]);
      expect(data.totals, ['', '255.00']);
      expect(data.totalRows, 3);
      final sent = graphql.where('RunAgentReport').single.variables;
      expect(sent['spec'], {'source': 'requests', 'x': 1});
      expect(sent['language'], 'en');
    });

    test('no totals stays null; the column labels follow the app language', () async {
      final graphql = ScriptedGraphQLService({
        'RunAgentReport': {
          'runAgentReport': {
            'columns': [
              {'key': 'ref', 'labelEn': 'Request', 'labelAr': 'الطلب', 'kind': 'text'},
            ],
            'rows': [],
            'totals': null,
            'totalRows': 0,
            'truncated': false,
          },
        },
      });
      final data = ((await source(graphql, language: 'ar').run(_request)) as Right).value as ReportData;
      expect((data.totals, data.columns.single.label), (null, 'الطلب'));
      expect(graphql.where('RunAgentReport').single.variables['language'], 'ar');
    });

    test('export asks for the format and decodes the file', () async {
      final graphql = ScriptedGraphQLService({
        'ExportAgentReport': {
          'exportAgentReport': {
            'filename': 'bookings-2026-09.csv',
            'contentType': 'text/csv',
            'contentBase64': base64Encode(utf8.encode('a,b\n1,2\n')),
            'rowCount': 1,
          },
        },
      });
      final file = ((await source(graphql).export(_request, ReportFormat.csv)) as Right).value as ReportFile;
      expect((file.filename, file.rowCount, utf8.decode(file.bytes)), ('bookings-2026-09.csv', 1, 'a,b\n1,2\n'));
      expect(graphql.where('ExportAgentReport').single.variables['format'], 'csv');
    });

    test('server codes become issues', () {
      ReportIssueKind kind(Failure f) => ReportIssue.from(f).kind;
      expect(kind(const ServerFailure('x', code: 'report_spec_invalid')), ReportIssueKind.specInvalid);
      expect(kind(const ServerFailure('x', code: 'report_too_large')), ReportIssueKind.tooLarge);
      expect(kind(const ServerFailure('x', code: 'report_not_found')), ReportIssueKind.notFound);
      expect(kind(const ServerFailure('x', code: 'permission_denied')), ReportIssueKind.forbidden);
      expect(kind(const ForbiddenFailure('x')), ReportIssueKind.forbidden);
      expect(kind(const NetworkFailure('x')), ReportIssueKind.offline);
    });
  });

  group('cubits', () {
    test('a failed run is flagged and a retry runs again', () async {
      final repo = _Repo()..runResult = const Left(NetworkFailure('offline'));
      final cubit = ReportResultCubit(repo, _request);
      await cubit.load();
      expect(cubit.state.issue?.kind, ReportIssueKind.offline);
      repo.runResult = Right(_data());
      await cubit.load();
      expect(cubit.state.data, isNotNull);
      expect(cubit.state.issue, isNull);
      expect(repo.runs, 2);
      await cubit.close();
    });

    test('the answer holding fewer rows than the report has counts as truncated', () {
      expect(ReportResultState(loading: false, data: _data(totalRows: 6000)).truncated, isTrue);
      expect(ReportResultState(loading: false, data: _data(truncated: true)).truncated, isTrue);
      expect(ReportResultState(loading: false, data: _data()).truncated, isFalse);
    });

    test('export: xlsx is the default, one export at a time, the format can be changed', () async {
      final repo = _Repo()..holdExport = Completer<void>();
      final cubit = ReportExportCubit(repo, _Exporter(), _request);
      expect(cubit.state.format, ReportFormat.xlsx);
      cubit.selectFormat(ReportFormat.csv);
      final first = cubit.export();
      await cubit.export();
      expect(repo.exported, [ReportFormat.csv]);
      cubit.selectFormat(ReportFormat.pdf);
      expect(cubit.state.format, ReportFormat.csv, reason: 'locked while exporting');
      repo.holdExport!.complete();
      await first;
      expect(cubit.state.status, ReportExportStatus.ready);
      await cubit.close();
    });

    test('a failed export keeps the choice so it can be tried again; a file that is too large says so', () async {
      final repo = _Repo()..exportResult = const Left(ServerFailure('x', code: 'report_too_large'));
      final cubit = ReportExportCubit(repo, _Exporter(), _request);
      await cubit.export();
      expect((cubit.state.status, cubit.state.issue?.kind), (ReportExportStatus.failed, ReportIssueKind.tooLarge));
      repo.exportResult = Right(ReportFile(filename: 'a.xlsx', bytes: Uint8List(1), rowCount: 1));
      await cubit.export();
      expect(cubit.state.status, ReportExportStatus.ready);
      await cubit.close();
    });

    test('download and share hand the file over; a failed save is reported', () async {
      final exporter = _Exporter();
      final cubit = ReportExportCubit(_Repo(), exporter, _request);
      await cubit.export();
      await cubit.download();
      await cubit.share();
      expect(exporter.saved, ['bookings-2026-09.xlsx']);
      expect(exporter.shared, ['bookings-2026-09.xlsx']);
      exporter.saveResult = const Left(ServerFailure('x'));
      await cubit.download();
      expect(cubit.state.outcome, ReportExportOutcome.saveFailed);
      await cubit.close();
    });
  });

  group('the result screen', () {
    testWidgets('loading, then the table with the row count and the totals', (tester) async {
      final repo = _Repo()..holdRun = Completer<void>();
      await _open(tester, repo, _Exporter());
      expect(find.text(_l10n.repGenerating), findsOneWidget);
      repo.holdRun!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('تقرير الحجوزات'), findsOneWidget);
      expect(find.text(toArabicIndicDigits(_l10n.repRowsCount(2))), findsOneWidget);
      expect(find.text('SB-1001'), findsOneWidget);
      expect(find.text('255.00'), findsOneWidget);
      expect(find.text(_l10n.repExport), findsOneWidget);
    });

    testWidgets('no rows: the empty state, and Export is disabled', (tester) async {
      final repo = _Repo()..runResult = const Right(ReportData(columns: _columns, rows: [], totals: null, totalRows: 0, truncated: false));
      await _open(tester, repo, _Exporter());
      expect(find.text(_l10n.repEmptyTitle), findsOneWidget);
      await tester.tap(find.text(_l10n.repExport));
      await tester.pump();
      expect(find.text(_l10n.repExportTitle), findsNothing);
    });

    testWidgets('more rows than the answer holds: a banner and "Export all"', (tester) async {
      final repo = _Repo()..runResult = Right(_data(truncated: true, totalRows: 6200));
      await _open(tester, repo, _Exporter());
      expect(find.textContaining(_l10n.repTruncatedTitle), findsOneWidget);
      expect(find.text(_l10n.repExportAll), findsOneWidget);
    });

    testWidgets('a report too large to run says so and offers to narrow it', (tester) async {
      final repo = _Repo()..runResult = const Left(ServerFailure('x', code: 'report_too_large'));
      await _open(tester, repo, _Exporter());
      expect(find.text(_l10n.repTruncatedTitle), findsOneWidget);
      expect(find.text(_l10n.repNarrowPeriod), findsOneWidget);
      expect(find.text(_l10n.repExport), findsNothing);
    });

    testWidgets('an error shows its own state and Retry runs the report again', (tester) async {
      final repo = _Repo()..runResult = const Left(ServerFailure('x', code: 'boom'));
      await _open(tester, repo, _Exporter());
      expect(find.text(_l10n.repGenerateErrorTitle), findsOneWidget);
      repo.runResult = Right(_data());
      await tester.tap(find.text(_l10n.commonRetry));
      await tester.pump();
      await tester.pump();
      expect(repo.runs, 2);
      expect(find.text('SB-1001'), findsOneWidget);
    });

    testWidgets('no permission: the access-denied view, no table, no actions', (tester) async {
      final repo = _Repo()..runResult = const Left(ForbiddenFailure('x'));
      await _open(tester, repo, _Exporter());
      expect(find.text(_l10n.repNoPermissionBody), findsOneWidget);
      expect(find.text(_l10n.repExport), findsNothing);
      expect(find.text('SB-1001'), findsNothing);
    });
  });

  group('the export sheet', () {
    Future<(_Repo, _Exporter)> openSheet(WidgetTester tester) async {
      final repo = _Repo();
      final exporter = _Exporter();
      await _open(tester, repo, exporter);
      await tester.tap(find.text(_l10n.repExport));
      await tester.pumpAndSettle();
      return (repo, exporter);
    }

    testWidgets('three formats, Excel chosen; exporting shows the busy label and then the ready file', (tester) async {
      final (repo, _) = await openSheet(tester);
      expect(find.text(_l10n.repExportTitle), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Excel · XLSX'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
      await tester.tap(find.text('CSV'));
      await tester.pump();
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(_l10n.repExport)));
      await tester.pumpAndSettle();
      expect(repo.exported, [ReportFormat.csv]);
      expect(find.text(_l10n.repReadyTitle), findsOneWidget);
      expect(find.text('bookings-2026-09.xlsx'), findsOneWidget);
      expect(find.text(_l10n.repShare), findsOneWidget);
      expect(find.text(_l10n.repDownload), findsOneWidget);
    });

    testWidgets('share and download hand the file to the system', (tester) async {
      final (_, exporter) = await openSheet(tester);
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(_l10n.repExport)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.repShare));
      await tester.pump();
      await tester.tap(find.text(_l10n.repDownload));
      await tester.pump();
      expect(exporter.shared, ['bookings-2026-09.xlsx']);
      expect(exporter.saved, ['bookings-2026-09.xlsx']);
    });

    testWidgets('a failed export shows the message and Retry', (tester) async {
      final (repo, _) = await openSheet(tester);
      repo.exportResult = const Left(NetworkFailure('offline'));
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(_l10n.repExport)));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.repExportFailed), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(_l10n.commonRetry)), findsOneWidget);
    });
  });
}
