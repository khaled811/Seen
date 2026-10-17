// Alternative top-up: cash and exchange house (Figma WAL-11). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/foundation/seen_icons.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
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
import 'package:seen_booking/features/wallet/presentation/widgets/wallet_cards.dart';

class _Repo implements WalletRepository {
  int calls = 0;
  TopUpMethod? method;
  String? reference;
  int? cents;

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
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, WalletTransaction>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    String? notes,
  }) async {
    calls++;
    this.method = method;
    reference = referenceNumber;
    cents = amountCents;
    return Right(WalletTransaction(
      id: 'n',
      type: TransactionType.topup,
      side: LedgerSide.credit,
      status: TransactionStatus.pending,
      amountCents: amountCents,
      currency: WalletCurrency.usd,
      createdAt: DateTime(2026, 10, 14),
      topUp: TopUpInfo(method: method, code: 'TU-5'),
    ));
  }
}

const _details = TopUpAlternativeDetails(
  recipientName: 'جُباري للسياحة والسفر',
  agentCode: 'AG-1183',
  branchAddress: 'صنعاء، شارع الزبيري',
);

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  Future<_Repo> open(WidgetTester tester) async {
    final repo = _Repo();
    final bloc = WalletBloc(
      getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
      getTransactionsUseCase: GetTransactionsUseCase(repo),
      requestTopUpUseCase: RequestTopUpUseCase(repo),
    )..add(const WalletLoadRequested());
    addTearDown(() => bloc.close().ignore());
    await tester.binding.setSurfaceSize(const Size(390, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context)
                .push(TopUpRequestScreen.route(bloc, alternativeDetails: _details)),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.runAsync(() async {
      while (bloc.state is! WalletLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('exchange house: transfer number, recipient and agent code', (tester) async {
    await open(tester);
    await tester.tap(find.text('شركة صرافة'));
    await tester.pumpAndSettle();
    expect(find.text('بيانات الحوالة من الصرافة'), findsOneWidget);
    expect(find.textContaining('رقم الحوالة'), findsOneWidget);
    expect(find.textContaining('اسم المستلم'), findsOneWidget);
    expect(find.text('جُباري للسياحة والسفر'), findsOneWidget);
    expect(find.text('رمز الوكيل'), findsOneWidget);
    expect(find.text('AG-1183'), findsOneWidget);
    // the bank card and the generic reference field are not for this method
    expect(find.text('الرقم المرجعي'), findsNothing);
    expect(find.text('الإيداع النقدي في الفرع'), findsNothing);
  });

  testWidgets('a typed transfer number gets a check mark', (tester) async {
    await open(tester);
    await tester.tap(find.text('شركة صرافة'));
    await tester.pumpAndSettle();
    final before = find.byIcon(SeenIcons.check).evaluate().length;
    await tester.enterText(find.byType(TextFormField).first, 'EX-4471029');
    await tester.pump();
    expect(find.byIcon(SeenIcons.check), findsNWidgets(before + 1));
  });

  testWidgets('cash: the branch steps with the agent code', (tester) async {
    await open(tester);
    await tester.tap(find.text('نقدًا'));
    await tester.pumpAndSettle();
    expect(find.text('الإيداع النقدي في الفرع'), findsOneWidget);
    expect(find.textContaining('١. توجّه إلى فرع صنعاء، شارع الزبيري'), findsOneWidget);
    expect(find.textContaining('٢. اذكر رمز الوكيل'), findsOneWidget);
    expect(find.textContaining('AG-1183'), findsWidgets);
    expect(find.text('٣. صوّر الإيصال وأرفقه هنا'), findsOneWidget);
    expect(find.text('بيانات الحوالة من الصرافة'), findsNothing);
  });

  testWidgets('submitting an exchange transfer sends its method, number and amount', (tester) async {
    final repo = await open(tester);
    await tester.tap(find.text('شركة صرافة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'EX-4471029');
    await tester.tap(find.text('500'));
    await tester.pump();
    await tester.tap(find.text('إرسال طلب الشحن'));
    await settle(tester);
    expect(repo.calls, 1);
    expect(repo.method, TopUpMethod.exchangeHouse);
    expect(repo.reference, 'EX-4471029');
    expect(repo.cents, 50000);
  });

  testWidgets('the exchange form needs the transfer number', (tester) async {
    final repo = await open(tester);
    await tester.tap(find.text('شركة صرافة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('500'));
    await tester.pump();
    await tester.tap(find.text('إرسال طلب الشحن'));
    await settle(tester);
    expect(repo.calls, 0);
  });
}
