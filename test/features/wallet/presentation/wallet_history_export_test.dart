// Top-up history (Figma WAL-04), submitted confirmation (WAL-05) and statement
// export (WAL-06). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/requests/domain/repositories/document_file_repository.dart';
import 'package:seen_booking/features/requests/domain/services/document_exporter.dart';
import 'package:seen_booking/features/requests/domain/usecases/request_document_usecases.dart';
import 'package:seen_booking/features/wallet/domain/entities/statement.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:seen_booking/features/wallet/domain/repositories/statement_repository.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/export_statement_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_transactions_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/request_top_up_usecase.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/statement_export_cubit.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/top_up_history_cubit.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:seen_booking/features/wallet/presentation/screens/top_up_history_screen.dart';
import 'package:seen_booking/features/wallet/presentation/screens/top_up_request_screen.dart';
import 'package:seen_booking/features/wallet/presentation/screens/top_up_submitted_screen.dart';
import 'package:seen_booking/features/wallet/presentation/widgets/statement_export_sheet.dart';

WalletTransaction _topUp(
  String id,
  TransactionStatus status,
  int cents, {
  TopUpMethod method = TopUpMethod.bankTransfer,
  String? code,
}) =>
    WalletTransaction(
      id: id,
      type: TransactionType.topup,
      side: LedgerSide.credit,
      status: status,
      amountCents: cents,
      currency: WalletCurrency.usd,
      createdAt: DateTime(2026, 10, 14, 9, 10),
      topUp: TopUpInfo(method: method, code: code),
    );

class _Repo implements WalletRepository {
  _Repo({this.pages = const [], this.failOnPage});

  /// What each page returns, 1-based.
  final List<List<WalletTransaction>> pages;
  final int? failOnPage;
  final requestedPages = <int>[];
  final requestedTypes = <TransactionType?>[];

  @override
  Future<Either<Failure, WalletBalance>> getBalance() async => const Right(
        WalletBalance(availableCents: 1, holdCents: 0, creditLimitCents: 0, currency: WalletCurrency.usd),
      );

  @override
  Future<Either<Failure, List<WalletTransaction>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    requestedPages.add(page);
    requestedTypes.add(type);
    if (failOnPage == page) return const Left(ServerFailure('boom'));
    return Right(page <= pages.length ? pages[page - 1] : const []);
  }

  @override
  Future<Either<Failure, WalletTransaction>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    String? notes,
  }) async =>
      Right(_topUp('new', TransactionStatus.pending, amountCents, code: 'TU-9'));
}

class _Statements implements StatementRepository {
  _Statements({this.fail = false});

  bool fail;
  final calls = <(DateTime, DateTime, StatementFormat)>[];

  @override
  Future<Either<Failure, StatementFile>> exportStatement({
    required DateTime from,
    required DateTime to,
    required StatementFormat format,
  }) async {
    calls.add((from, to, format));
    if (fail) return const Left(ServerFailure('x'));
    return Right(StatementFile(url: 'u', fileName: 'statement.${format.extension}'));
  }
}

class _Files implements DocumentFileRepository {
  _Files({this.fail = false});

  final bool fail;

  @override
  Future<Either<Failure, Uint8List>> fetch(String url) async =>
      fail ? const Left(NetworkFailure('x')) : Right(Uint8List.fromList([1, 2, 3]));
}

class _Exporter implements DocumentExporter {
  _Exporter({this.saveResult = const Right(true)});

  final Either<Failure, bool> saveResult;
  final saved = <String>[];
  final shared = <String>[];

  @override
  Future<Either<Failure, bool>> save(String fileName, Uint8List bytes) async {
    saved.add(fileName);
    return saveResult;
  }

  @override
  Future<Either<Failure, bool>> share(String fileName, Uint8List bytes) async {
    shared.add(fileName);
    return const Right(true);
  }
}

StatementExportCubit _exportCubit(_Statements statements, _Files files, _Exporter exporter) => StatementExportCubit(
      exportStatement: ExportStatementUseCase(statements),
      fetchDocument: FetchDocumentFileUseCase(files),
      saveDocument: SaveDocumentUseCase(exporter),
      shareDocument: ShareDocumentUseCase(exporter),
    );

WalletBloc _walletBloc(_Repo repo) => WalletBloc(
      getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
      getTransactionsUseCase: GetTransactionsUseCase(repo),
      requestTopUpUseCase: RequestTopUpUseCase(repo),
    );

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    InjectionContainer.instance.init();
  });

  group('TopUpHistoryCubit', () {
    test('loads top-ups only, pages on demand without repeating rows, and filters by status', () async {
      final page1 = [for (var i = 1; i <= 2; i++) _topUp('a$i', TransactionStatus.pending, 1000 * i)];
      final page2 = [_topUp('a2', TransactionStatus.pending, 2000), _topUp('b1', TransactionStatus.rejected, 500)];
      final repo = _Repo(pages: [page1, page2]);
      final cubit = TopUpHistoryCubit(getTransactions: GetTransactionsUseCase(repo), pageSize: 2);
      await cubit.load();
      expect(repo.requestedTypes, [TransactionType.topup]);
      expect(cubit.state.items.length, 2);
      expect(cubit.state.hasMore, true);
      await cubit.loadMore();
      expect(repo.requestedPages, [1, 2]);
      expect(cubit.state.items.map((t) => t.id), ['a1', 'a2', 'b1']);
      cubit.setFilter(TopUpHistoryFilter.rejected);
      expect(cubit.state.visible.map((t) => t.id), ['b1']);
      cubit.setFilter(TopUpHistoryFilter.approved);
      expect(cubit.state.visible, isEmpty);
      await cubit.close();
    });

    test('a failed first page is a failure; a failed next page keeps the list', () async {
      final failing = TopUpHistoryCubit(
        getTransactions: GetTransactionsUseCase(_Repo(failOnPage: 1)),
      );
      await failing.load();
      expect(failing.state.status, TopUpHistoryStatus.failure);
      await failing.close();

      final repo = _Repo(pages: [
        [_topUp('a1', TransactionStatus.pending, 1), _topUp('a2', TransactionStatus.pending, 2)],
      ], failOnPage: 2);
      final cubit = TopUpHistoryCubit(getTransactions: GetTransactionsUseCase(repo), pageSize: 2);
      await cubit.load();
      await cubit.loadMore();
      expect(cubit.state.items.length, 2);
      expect(cubit.state.moreFailed, true);
      expect(cubit.state.hasMore, true);
      await cubit.close();
    });
  });

  group('TopUpHistoryScreen (WAL-04)', () {
    Future<_Repo> open(WidgetTester tester, List<List<WalletTransaction>> pages, {int pageSize = 20}) async {
      final repo = _Repo(pages: pages);
      final bloc = _walletBloc(repo);
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: _app(TopUpHistoryScreen(
          createCubit: () => TopUpHistoryCubit(getTransactions: GetTransactionsUseCase(repo), pageSize: pageSize),
        )),
      ));
      await settle(tester);
      return repo;
    }

    testWidgets('lists the requests with amount, method, date and status chip', (tester) async {
      await open(tester, [
        [
          _topUp('1', TransactionStatus.pending, 50000),
          _topUp('2', TransactionStatus.approved, 100000),
          _topUp('3', TransactionStatus.rejected, 100000, method: TopUpMethod.cash),
        ],
      ]);
      expect(find.text('سجل الشحن'), findsOneWidget);
      expect(find.textContaining('500.00 USD'), findsOneWidget);
      expect(find.textContaining('تحويل بنكي'), findsNWidgets(2));
      expect(find.textContaining('نقدًا'), findsOneWidget);
      expect(find.text('مكتمل'), findsOneWidget);
      // chips on rows + filter chips share these words
      expect(find.text('مرفوض'), findsNWidgets(2));
    });

    testWidgets('a status chip narrows the list and an empty result says so', (tester) async {
      await open(tester, [
        [_topUp('1', TransactionStatus.pending, 50000), _topUp('3', TransactionStatus.rejected, 70000)],
      ]);
      await tester.tap(find.text('معتمد'));
      await tester.pump();
      expect(find.text('لا توجد طلبات شحن بهذه الحالة.'), findsOneWidget);
      await tester.tap(find.text('الكل'));
      await tester.pump();
      expect(find.textContaining('700.00 USD'), findsOneWidget);
    });

    testWidgets('no requests at all shows the empty state', (tester) async {
      await open(tester, const []);
      expect(find.text('لا توجد طلبات شحن بعد.'), findsOneWidget);
    });

    testWidgets('"load more" appears when a full page came back and fetches the next', (tester) async {
      final repo = await open(
        tester,
        [
          [_topUp('1', TransactionStatus.pending, 10000), _topUp('2', TransactionStatus.pending, 20000)],
          [_topUp('3', TransactionStatus.approved, 30000)],
        ],
        pageSize: 2,
      );
      expect(find.text('تحميل المزيد…'), findsOneWidget);
      await tester.tap(find.text('تحميل المزيد…'));
      await settle(tester);
      expect(repo.requestedPages, [1, 2]);
      expect(find.textContaining('300.00 USD'), findsOneWidget);
      expect(find.text('تحميل المزيد…'), findsNothing); // the short page was the last
    });
  });

  group('TopUpSubmittedScreen (WAL-05)', () {
    testWidgets('submitting the form lands on the confirmation with the reference', (tester) async {
      final repo = _Repo();
      final bloc = _walletBloc(repo)..add(const WalletLoadRequested());
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(TopUpRequestScreen.route(bloc)),
            child: const Text('go'),
          ),
        ),
      )));
      await tester.runAsync(() async {
        while (bloc.state is! WalletLoaded) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      });
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('500'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), 'TRX-77');
      await tester.tap(find.text('إرسال طلب الشحن'));
      await settle(tester);

      expect(find.byType(TopUpSubmittedScreen), findsOneWidget);
      expect(find.text('أُرسل طلب الشحن'), findsOneWidget);
      expect(find.textContaining('TU-9'), findsOneWidget);
      expect(find.text('قيد المراجعة'), findsOneWidget);
      expect(find.text('عرض الطلب'), findsOneWidget);

      await tester.tap(find.text('العودة للمحفظة'));
      await tester.pumpAndSettle();
      expect(find.byType(TopUpSubmittedScreen), findsNothing);
      expect(find.byType(TopUpRequestScreen), findsNothing); // back on the wallet host
    });

    testWidgets('without a code it still confirms, and "View request" opens the request', (tester) async {
      final bloc = _walletBloc(_Repo());
      addTearDown(() => bloc.close().ignore());
      await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: _app(TopUpSubmittedScreen(transaction: _topUp('x', TransactionStatus.pending, 100))),
      ));
      await settle(tester);
      expect(find.text('تراجع المالية الطلب وسيصلك إشعار عند الإضافة إلى رصيدك.'), findsOneWidget);
      await tester.tap(find.text('عرض الطلب'));
      await settle(tester);
      expect(find.text('طلب شحن'), findsOneWidget); // the pending top-up detail
    });
  });

  group('StatementExportCubit', () {
    test('a download builds the file, fetches it and saves it', () async {
      final statements = _Statements();
      final exporter = _Exporter();
      final cubit = _exportCubit(statements, _Files(), exporter);
      final states = <StatementExportState>[];
      cubit.stream.listen(states.add);
      await cubit.export(
        range: StatementRange(DateTime(2026, 10), DateTime(2026, 10, 14)),
        format: StatementFormat.excel,
        action: StatementAction.download,
      );
      expect(statements.calls.single.$3, StatementFormat.excel);
      expect(exporter.saved, ['statement.xlsx']);
      expect(states.first.status, StatementStatus.generating);
      expect(cubit.state.outcome, StatementOutcome.saved);
      await cubit.close();
    });

    test('a cancelled save and a successful share show no message', () async {
      final exporter = _Exporter(saveResult: const Right(false));
      final cubit = _exportCubit(_Statements(), _Files(), exporter);
      final range = StatementRange(DateTime(2026, 10), DateTime(2026, 10, 14));
      await cubit.export(range: range, format: StatementFormat.pdf, action: StatementAction.download);
      expect(cubit.state.outcome, isNull);
      await cubit.export(range: range, format: StatementFormat.pdf, action: StatementAction.share);
      expect(exporter.shared, ['statement.pdf']);
      expect(cubit.state.outcome, isNull);
      expect(cubit.state.status, StatementStatus.idle);
      await cubit.close();
    });

    test('a server failure or a failed download is "failed"; a failed save is reported', () async {
      final range = StatementRange(DateTime(2026, 10), DateTime(2026, 10, 14));
      var cubit = _exportCubit(_Statements(fail: true), _Files(), _Exporter());
      await cubit.export(range: range, format: StatementFormat.pdf, action: StatementAction.download);
      expect(cubit.state.status, StatementStatus.failed);
      await cubit.close();

      cubit = _exportCubit(_Statements(), _Files(fail: true), _Exporter());
      await cubit.export(range: range, format: StatementFormat.pdf, action: StatementAction.share);
      expect(cubit.state.status, StatementStatus.failed);
      await cubit.close();

      cubit = _exportCubit(_Statements(), _Files(), _Exporter(saveResult: const Left(ServerFailure('x'))));
      await cubit.export(range: range, format: StatementFormat.pdf, action: StatementAction.download);
      expect(cubit.state.outcome, StatementOutcome.saveFailed);
      await cubit.close();
    });

    test('the periods cover this month and the last three months', () {
      final now = DateTime(2026, 10, 14, 18);
      final month = StatementRange.forPeriod(StatementPeriod.thisMonth, now);
      expect((month.from, month.to), (DateTime(2026, 10), DateTime(2026, 10, 14)));
      final three = StatementRange.forPeriod(StatementPeriod.threeMonths, now);
      expect((three.from, three.to), (DateTime(2026, 7, 14), DateTime(2026, 10, 14)));
    });
  });

  group('statement export sheet (WAL-06)', () {
    Future<_Statements> open(
      WidgetTester tester, {
      bool failStatement = false,
      _Exporter? exporter,
      Future<DateTimeRange?> Function(BuildContext, DateTime)? pick,
    }) async {
      final statements = _Statements(fail: failStatement);
      final theExporter = exporter ?? _Exporter();
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showStatementExportSheet(
              context,
              createCubit: () => _exportCubit(statements, _Files(), theExporter),
              pickRange: pick,
              now: () => DateTime(2026, 10, 14, 12),
            ),
            child: const Text('open-sheet'),
          ),
        ),
      )));
      await tester.tap(find.text('open-sheet'));
      await tester.pumpAndSettle();
      return statements;
    }

    testWidgets('shows the periods, formats and both actions', (tester) async {
      await open(tester);
      expect(find.text('تصدير كشف الحساب'), findsOneWidget);
      for (final label in const ['هذا الشهر', '٣ أشهر', 'مخصص', 'PDF', 'Excel', 'تنزيل', 'مشاركة']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('downloading sends the chosen period and format, saves, then closes with a message',
        (tester) async {
      final exporter = _Exporter();
      final statements = await open(tester, exporter: exporter);
      await tester.tap(find.text('Excel'));
      await tester.pump();
      await tester.tap(find.text('٣ أشهر'));
      await tester.pump();
      await tester.tap(find.text('تنزيل'));
      await tester.pumpAndSettle();
      final call = statements.calls.single;
      expect((call.$1, call.$2, call.$3), (DateTime(2026, 7, 14), DateTime(2026, 10, 14), StatementFormat.excel));
      expect(exporter.saved, ['statement.xlsx']);
      expect(find.text('تصدير كشف الحساب'), findsNothing);
      expect(find.text('تم حفظ الكشف.'), findsOneWidget);
    });

    testWidgets('a custom period uses the range the agent picked', (tester) async {
      final statements = await open(
        tester,
        pick: (_, __) async => DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)),
      );
      await tester.tap(find.text('مخصص'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مشاركة'));
      await tester.pumpAndSettle();
      final call = statements.calls.single;
      expect((call.$1, call.$2), (DateTime(2026, 9, 1), DateTime(2026, 9, 30)));
    });

    testWidgets('a failure shows the error with a retry that tries again', (tester) async {
      final statements = await open(tester, failStatement: true);
      await tester.tap(find.text('تنزيل'));
      await tester.pumpAndSettle();
      expect(find.text('تعذّر إنشاء الكشف. حاول مرة أخرى.'), findsOneWidget);
      statements.fail = false;
      await tester.tap(find.text('إعادة'));
      await tester.pumpAndSettle();
      expect(statements.calls.length, 2);
      expect(find.text('تعذّر إنشاء الكشف. حاول مرة أخرى.'), findsNothing);
    });
  });
}
