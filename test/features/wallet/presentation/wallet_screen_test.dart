// Wallet screen (Figma 11): header, usage card, actions, pending top-up and the
// ledger with its All / Debits / Credits segments, over a real WalletBloc.

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
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/entities/top_up_options.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_transactions_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/request_top_up_usecase.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:seen_booking/features/wallet/presentation/screens/wallet_screen.dart';

WalletTransaction _tx(String id, TransactionType type, LedgerSide side, int cents,
        {TransactionStatus status = TransactionStatus.approved, String? ref}) =>
    WalletTransaction(
      id: id,
      type: type,
      side: side,
      status: status,
      amountCents: cents,
      currency: WalletCurrency.usd,
      createdAt: DateTime(2026, 11, 10, 14, 2),
      referenceId: ref,
    );

class _Repo implements WalletRepository {
  @override
  Future<Either<Failure, WalletBalance>> getBalance() async => const Right(
        WalletBalance(availableCents: 132200, holdCents: 21000, creditLimitCents: 200000, currency: WalletCurrency.usd),
      );

  @override
  Future<Either<Failure, List<WalletTransaction>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async =>
      Right([
        _tx('1', TransactionType.hold, LedgerSide.debit, 15000, ref: 'SB-20470'),
        _tx('2', TransactionType.topup, LedgerSide.credit, 100000, ref: 'TRX-1'),
        _tx('3', TransactionType.topup, LedgerSide.credit, 50000, status: TransactionStatus.pending),
      ]);

  @override
  Future<Either<Failure, TopUpOptions>> getTopUpOptions() async => const Left(ServerFailure('x'));

  @override
  Future<Either<Failure, WalletTransaction>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    required String idempotencyKey,
    String? paymentAccountId,
    String? receiptFileId,
  }) async =>
      throw UnimplementedError();
}

class _ForbiddenRepo extends _Repo {
  @override
  Future<Either<Failure, WalletBalance>> getBalance() async => const Left(ForbiddenFailure());
}

void main() {
  late WalletBloc bloc;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    InjectionContainer.instance.init();
  });

  setUp(() {
    final repo = _Repo();
    bloc = WalletBloc(
      getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
      getTransactionsUseCase: GetTransactionsUseCase(repo),
      requestTopUpUseCase: RequestTopUpUseCase(repo),
    )..add(const WalletLoadRequested());
  });

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => bloc.close().ignore());
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(BlocProvider<WalletBloc>.value(
      value: bloc,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        home: const WalletView(),
      ),
    ));
    await tester.runAsync(() async {
      while (bloc.state is! WalletLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pump();
  }

  testWidgets('shows the title, usage amounts, actions, pending top-up and ledger rows', (tester) async {
    await open(tester);
    expect(find.text('المحفظة'), findsOneWidget);
    expect(find.textContaining('1,322.00 USD'), findsWidgets); // usage card (and balance chips)
    expect(find.text('شحن الرصيد'), findsOneWidget);
    expect(find.text('تحويل لوكيل'), findsOneWidget);
    expect(find.text('قيد الانتظار'), findsWidgets); // pending card + flagged row
    expect(find.text('−150.00'), findsOneWidget);
    expect(find.text('+1,000.00'), findsOneWidget);
    expect(find.textContaining('١٠ نوفمبر'), findsWidgets);
  });

  testWidgets('the Debits segment keeps only money-out rows', (tester) async {
    await open(tester);
    await tester.tap(find.text('خصم'));
    await tester.pump();
    expect(find.text('−150.00'), findsOneWidget);
    expect(find.text('+1,000.00'), findsNothing);
  });

  testWidgets('the Credits segment keeps only money-in rows', (tester) async {
    await open(tester);
    await tester.tap(find.text('إيداع'));
    await tester.pump();
    expect(find.text('+1,000.00'), findsOneWidget);
    expect(find.text('−150.00'), findsNothing);
  });

  testWidgets('the statement link opens the export sheet', (tester) async {
    await open(tester);
    await tester.tap(find.text('كشف الحساب'));
    await tester.pumpAndSettle();
    expect(find.text('تصدير كشف الحساب'), findsOneWidget);
    expect(find.text('هذا الشهر'), findsOneWidget);
    expect(find.text('تنزيل'), findsOneWidget);
  });

  testWidgets('a 403 shows the no-permission screen instead of a retry (SYS-03)', (tester) async {
    final repo = _ForbiddenRepo();
    final denied = WalletBloc(
      getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
      getTransactionsUseCase: GetTransactionsUseCase(repo),
      requestTopUpUseCase: RequestTopUpUseCase(repo),
    )..add(const WalletLoadRequested());
    addTearDown(() => denied.close().ignore());
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(BlocProvider<WalletBloc>.value(
      value: denied,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        home: const WalletView(),
      ),
    ));
    await tester.runAsync(() async {
      while (denied.state is! WalletFailure) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pump();
    expect((denied.state as WalletFailure).forbidden, isTrue);
    expect(find.text('ليس لديك صلاحية'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
    expect(find.text('طلب الصلاحية'), findsOneWidget);
    expect(find.text('العودة للرئيسية'), findsOneWidget);
  });
}
