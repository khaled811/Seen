// Wallet balance states (Figma WAL-08), empty ledger (WAL-09) and the balance
// breakdown (WAL-10). Arabic / RTL.

import 'dart:async';

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
import 'package:seen_booking/core/presentation/foundation/seen_icons.dart';
import 'package:seen_booking/core/presentation/widgets/balance_card.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/wallet/data/models/wallet_balance_dto.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_transactions_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/request_top_up_usecase.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:seen_booking/features/wallet/presentation/screens/top_up_request_screen.dart';
import 'package:seen_booking/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:seen_booking/features/wallet/presentation/widgets/wallet_balance_widgets.dart';

WalletBalance _balance({
  int available = 132200,
  int hold = 21000,
  int limit = 200000,
  int? used,
}) =>
    WalletBalance(
      availableCents: available,
      holdCents: hold,
      creditLimitCents: limit,
      currency: WalletCurrency.usd,
      creditUsedCents: used,
    );

WalletTransaction _tx(String id, TransactionType type, LedgerSide side, int cents,
        {TransactionStatus status = TransactionStatus.approved}) =>
    WalletTransaction(
      id: id,
      type: type,
      side: side,
      status: status,
      amountCents: cents,
      currency: WalletCurrency.usd,
      createdAt: DateTime(2026, 10, 14, 10, 45),
      referenceId: 'SB-$id',
    );

class _Repo implements WalletRepository {
  _Repo({WalletBalance? balance, List<WalletTransaction>? transactions})
      : balance = balance ?? _balance(),
        transactions = transactions ??
            [
              _tx('1', TransactionType.hold, LedgerSide.debit, 15000, status: TransactionStatus.pending),
              _tx('2', TransactionType.finalDeduction, LedgerSide.debit, 15000),
              _tx('3', TransactionType.refund, LedgerSide.credit, 6000),
            ];

  WalletBalance balance;
  List<WalletTransaction> transactions;
  bool failing = false;

  /// Holds the balance back until completed (to look at the loading state).
  Completer<void>? gate;

  @override
  Future<Either<Failure, WalletBalance>> getBalance() async {
    await gate?.future;
    return failing ? const Left(NetworkFailure('offline')) : Right(balance);
  }

  @override
  Future<Either<Failure, List<WalletTransaction>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async =>
      Right(transactions);

  @override
  Future<Either<Failure, WalletTransaction>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    String? notes,
  }) async =>
      throw UnimplementedError();
}

WalletBloc _bloc(_Repo repo) => WalletBloc(
      getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
      getTransactionsUseCase: GetTransactionsUseCase(repo),
      requestTopUpUseCase: RequestTopUpUseCase(repo),
    );

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

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    InjectionContainer.instance.init();
  });

  group('WalletBalance', () {
    test('zero means nothing available and nothing held', () {
      expect(_balance(available: 0, hold: 0).isZero, true);
      expect(_balance(available: 0, hold: 100).isZero, false);
    });

    test('over the limit means owing more than the credit limit allows', () {
      expect(_balance(available: -12000, limit: 0).overLimitCents, 12000);
      expect(_balance(available: -50000, limit: 100000).isOverLimit, false); // using credit, within it
      expect(_balance(available: -150000, limit: 100000).overLimitCents, 50000);
      expect(_balance().isOverLimit, false);
    });

    test('the credit bar needs both the used amount and a limit', () {
      expect(_balance(used: 108000).creditUsedFraction, closeTo(0.54, 0.001));
      expect(_balance(used: 999999).creditUsedFraction, 1.0);
      expect(_balance().creditUsedFraction, isNull);
      expect(_balance(used: 100, limit: 0).creditUsedFraction, isNull);
    });

    test('creditUsedAmount maps from the wire', () {
      final b = WalletBalanceDto.fromJson(const {
        'availableAmount': '1322.00',
        'holdAmount': '210.00',
        'creditLimitAmount': '2000.00',
        'creditUsedAmount': '1080.00',
        'currency': 'USD',
      }).toEntity();
      expect(b.creditUsedCents, 108000);
    });
  });

  group('WalletBloc refresh', () {
    test('a failed refresh keeps the last numbers and says why; a later success clears it', () async {
      final repo = _Repo();
      final bloc = _bloc(repo)..add(const WalletLoadRequested());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);
      repo.failing = true;
      bloc.add(const WalletLoadRequested());
      final failed = await bloc.stream.firstWhere((s) => s is WalletLoaded && s.refreshError != null) as WalletLoaded;
      expect(failed.balance.availableCents, 132200);
      repo.failing = false;
      bloc.add(const WalletLoadRequested());
      final ok = await bloc.stream.firstWhere((s) => s is WalletLoaded && s.refreshError == null) as WalletLoaded;
      expect(ok.refreshError, isNull);
      await bloc.close();
    });

    test('a failure with nothing to show is still a failure', () async {
      final repo = _Repo()..failing = true;
      final bloc = _bloc(repo)..add(const WalletLoadRequested());
      expect(await bloc.stream.firstWhere((s) => s is WalletFailure), isA<WalletFailure>());
      await bloc.close();
    });
  });

  group('wallet screen', () {
    Future<(_Repo, WalletBloc)> open(WidgetTester tester, _Repo repo) async {
      final bloc = _bloc(repo)..add(const WalletLoadRequested());
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(BlocProvider<WalletBloc>.value(value: bloc, child: _app(const WalletView())));
      await tester.runAsync(() async {
        while (bloc.state is! WalletLoaded) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      });
      await tester.pump();
      return (repo, bloc);
    }

    testWidgets('WAL-10: the breakdown card, the legend and typed ledger chips', (tester) async {
      await open(tester, _Repo(balance: _balance(used: 108000)));
      expect(find.text('الرصيد المتاح للطلبات'), findsOneWidget);
      expect(find.text('1,322.00 USD'), findsOneWidget);
      expect(find.text('الإجمالي'), findsOneWidget);
      expect(find.text('1,532.00 USD'), findsOneWidget);
      expect(find.text('محجوز · قيد المراجعة'), findsOneWidget);
      expect(find.text('210.00 USD'), findsOneWidget);
      expect(find.textContaining('استخدام حد الائتمان'), findsOneWidget);
      expect(find.text('54%'), findsOneWidget);
      expect(find.text('كيف نحسب رصيدك'), findsOneWidget);
      expect(find.text('يمكنك استخدامه لطلبات جديدة الآن'), findsOneWidget);
      // ledger rows: held / deducted / returned
      expect(find.text('مخصوم'), findsOneWidget);
      expect(find.text('مُعاد'), findsOneWidget);
      expect(find.text('محجوز'), findsWidgets);
    });

    testWidgets('without the credit-used figure the bar is left out', (tester) async {
      await open(tester, _Repo());
      expect(find.textContaining('استخدام حد الائتمان'), findsNothing);
    });

    testWidgets('no credit limit means no credit line in the legend', (tester) async {
      await open(tester, _Repo(balance: _balance(limit: 0)));
      expect(find.text('حد الائتمان'), findsNothing);
    });

    testWidgets('WAL-08 hidden: the eye masks the amount and says how to show it', (tester) async {
      await open(tester, _Repo());
      await tester.tap(find.byIcon(SeenIcons.eye));
      await tester.pump();
      expect(find.text('••••• USD'), findsOneWidget);
      expect(find.text('اضغط على العين لإظهار الرصيد'), findsOneWidget);
      expect(find.text('1,532.00 USD'), findsNothing);
    });

    testWidgets('WAL-08 zero: invites a top-up instead of showing empty parts', (tester) async {
      await open(tester, _Repo(balance: _balance(available: 0, hold: 0)));
      expect(find.text('0.00 USD'), findsOneWidget);
      expect(find.text('اشحن رصيدك لبدء الطلبات'), findsOneWidget);
      expect(find.text('الإجمالي'), findsNothing);
    });

    testWidgets('WAL-08 over limit: a red card with what to pay', (tester) async {
      await open(tester, _Repo(balance: _balance(available: -12000, hold: 0, limit: 0)));
      expect(find.text('تجاوزت حد الائتمان'), findsOneWidget);
      expect(find.text('−120.00 USD'), findsOneWidget);
      expect(find.textContaining('سدّد'), findsOneWidget);
      expect(find.textContaining('لاستئناف الطلبات'), findsOneWidget);
    });

    testWidgets('WAL-08 loading: a skeleton, not a spinner over blank', (tester) async {
      final repo = _Repo()..gate = Completer<void>();
      final bloc = _bloc(repo);
      addTearDown(() => bloc.close().ignore());
      await tester.pumpWidget(BlocProvider<WalletBloc>.value(value: bloc, child: _app(const WalletView())));
      bloc.add(const WalletLoadRequested());
      await tester.pump();
      expect(find.byType(WalletLoadingSkeleton), findsOneWidget);
      repo.gate!.complete();
      await tester.runAsync(() => bloc.stream.firstWhere((s) => s is WalletLoaded));
      await tester.pump();
      expect(find.byType(WalletLoadingSkeleton), findsNothing);
    });

    testWidgets('WAL-08 error: a banner with the last known value, retry clears it', (tester) async {
      final (repo, bloc) = await open(tester, _Repo());
      repo.failing = true;
      bloc.add(const WalletLoadRequested());
      await settle(tester);
      expect(find.textContaining('تعذّر تحديث الرصيد. آخر قيمة معروفة'), findsOneWidget);
      expect(find.textContaining('1,322.00 USD'), findsNWidgets(2)); // banner + the card's own amount
      repo.failing = false;
      await tester.tap(find.text('إعادة'));
      await settle(tester);
      expect(find.textContaining('تعذّر تحديث الرصيد'), findsNothing);
    });

    testWidgets('WAL-09: an empty ledger offers the top-up', (tester) async {
      await open(tester, _Repo(transactions: const []));
      expect(find.text('لا توجد عمليات بعد'), findsOneWidget);
      expect(find.text('اشحن رصيدك الآن لبدء استخدام المحفظة.'), findsOneWidget);
      // the empty state's button and the actions row both say "Top up"
      expect(find.text('شحن الرصيد'), findsNWidgets(2));
    });

    testWidgets('WAL-09: the segment with no rows names what is missing, and the button tops up', (tester) async {
      await open(tester, _Repo(transactions: [_tx('2', TransactionType.finalDeduction, LedgerSide.debit, 15000)]));
      await tester.tap(find.text('إيداع'));
      await tester.pump();
      expect(find.text('لا توجد إيداعات بعد'), findsOneWidget);
      await tester.tap(find.text('شحن الرصيد').last);
      await tester.pumpAndSettle();
      expect(find.byType(TopUpRequestScreen), findsOneWidget);
    });
  });

  testWidgets('the shared balance card shows its hints instead of the chips', (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: SeenBalanceCard(
        available: 0,
        hold: 0,
        caption: 'رصيد دائن',
        holdLabel: (a) => 'محجوز $a',
        showSemanticLabel: 'إظهار الرصيد',
        hideSemanticLabel: 'إخفاء الرصيد',
        hint: 'اشحن رصيدك لبدء الطلبات',
        hiddenHint: 'اضغط على العين',
      ),
    )));
    expect(find.text('اشحن رصيدك لبدء الطلبات'), findsOneWidget);
    expect(find.textContaining('محجوز'), findsNothing);
    await tester.tap(find.byIcon(SeenIcons.eye));
    await tester.pump();
    expect(find.text('اضغط على العين'), findsOneWidget);
  });
}
