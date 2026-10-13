// Phase 3E widgets: ledger row, usage / pending / bank cards, the full-page
// top-up flow and the sub-agent card. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/foundation/seen_vectors.dart';
import 'package:seen_booking/core/presentation/widgets/status.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/seen_colors.dart';
import 'package:seen_booking/features/agents/presentation/widgets/seen_sub_agent_card.dart';
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
import 'package:seen_booking/features/wallet/presentation/widgets/ledger_row.dart';
import 'package:seen_booking/features/wallet/presentation/widgets/wallet_cards.dart';

const _balance = WalletBalance(
  availableCents: 100000,
  holdCents: 5000,
  creditLimitCents: 500000,
  currency: WalletCurrency.usd,
);

class _FakeRepo implements WalletRepository {
  int topUpCalls = 0;
  int? lastAmountCents;
  TopUpMethod? lastMethod;
  Either<Failure, WalletTransaction> result = Right(WalletTransaction(
    id: 't1',
    type: TransactionType.topup,
    side: LedgerSide.credit,
    status: TransactionStatus.pending,
    amountCents: 50000,
    currency: WalletCurrency.usd,
    createdAt: DateTime(2026, 1, 1),
  ));

  @override
  Future<Either<Failure, WalletBalance>> getBalance() async => const Right(_balance);

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
    topUpCalls++;
    lastAmountCents = amountCents;
    lastMethod = method;
    return result;
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

Future<void> _pumpCard(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child))));
  await tester.pump();
}

/// The bloc's use-case futures complete in real time, not fake-async time.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  group('SeenLedgerRow', () {
    testWidgets('credit shows +amount over USD in a left-to-right run, with its meta line', (tester) async {
      await _pumpCard(
        tester,
        const SeenLedgerRow(
          type: SeenLedgerType.credit,
          title: 'شحن رصيد · REF-1',
          meta: '١٠ نوفمبر · 14:02',
          amount: 1000,
          iconAsset: SeenVectors.walletTxnBank,
        ),
      );
      expect(find.text('+1,000.00'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('شحن رصيد · REF-1'), findsOneWidget);
      expect(find.text('١٠ نوفمبر · 14:02'), findsOneWidget);
    });

    testWidgets('debit uses the minus sign and can carry a status chip', (tester) async {
      await _pumpCard(
        tester,
        const SeenLedgerRow(
          type: SeenLedgerType.debit,
          title: 'حجز',
          meta: '٩ نوفمبر · 09:30',
          amount: 85.5,
          iconAsset: SeenVectors.iconRequests,
          statusChip: SeenStatusChip(status: SeenRequestStatus.underReview, label: 'قيد المراجعة'),
        ),
      );
      expect(find.text('−85.50'), findsOneWidget);
      expect(find.text('قيد المراجعة'), findsOneWidget);
    });
  });

  group('wallet cards', () {
    testWidgets('usage card shows held and available amounts', (tester) async {
      await _pumpCard(
        tester,
        SeenWalletUsageCard(
          available: 1000,
          hold: 50,
          heldLabel: 'محجوز',
          availableLabel: 'متاح',
          heldValue: (a) => 'محجوز $a',
          availableValue: (a) => 'متاح $a',
        ),
      );
      expect(find.textContaining('50.00 USD'), findsOneWidget);
      expect(find.textContaining('1,000.00 USD'), findsOneWidget);
    });

    testWidgets('usage card tolerates a zero balance', (tester) async {
      await _pumpCard(
        tester,
        SeenWalletUsageCard(
          available: 0,
          hold: 0,
          heldLabel: 'محجوز',
          availableLabel: 'متاح',
          heldValue: (a) => a,
          availableValue: (a) => a,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('bank details card copies the IBAN to the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await _pumpCard(
        tester,
        const SeenBankDetailsCard(
          details: TopUpBankDetails(bankName: 'بنك', accountName: 'الشركة', iban: 'XX00 1234'),
          ibanLabel: 'IBAN',
          beneficiaryLabel: 'المستفيد',
          currencyLabel: 'العملة',
          copyLabel: 'نسخ',
          copiedMessage: 'تم النسخ.',
        ),
      );
      await tester.tap(find.bySemanticsLabel('نسخ'));
      await tester.pump();
      expect(copied, 'XX00 1234');
      expect(find.text('تم النسخ.'), findsOneWidget);
    });
  });

  group('SeenSubAgentCard', () {
    testWidgets('shows initial, name, code, status and balance; a tap fires', (tester) async {
      var taps = 0;
      await _pumpCard(
        tester,
        SeenSubAgentCard(
          name: 'فرع جدة',
          caption: 'JED-01',
          balance: 1250,
          suspended: false,
          statusLabel: 'نشط',
          onTap: () => taps++,
        ),
      );
      expect(find.text('فرع جدة'), findsOneWidget);
      expect(find.text('ف'), findsOneWidget);
      expect(find.text('نشط'), findsOneWidget);
      expect(find.textContaining('JED-01'), findsOneWidget);
      expect(find.textContaining('1,250.00 USD'), findsOneWidget);
      await tester.tap(find.text('فرع جدة'));
      expect(taps, 1);
    });

    testWidgets('the stat tile shows its caption and value', (tester) async {
      await _pumpCard(tester, const SeenAgentStatTile(label: 'وكيل نشط', value: '١٢'));
      expect(find.text('وكيل نشط'), findsOneWidget);
      expect(find.text('١٢'), findsOneWidget);
    });
  });

  group('TopUpRequestScreen', () {
    late _FakeRepo repo;
    late WalletBloc bloc;

    setUp(() {
      repo = _FakeRepo();
      bloc = WalletBloc(
        getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
        getTransactionsUseCase: GetTransactionsUseCase(repo),
        requestTopUpUseCase: RequestTopUpUseCase(repo),
      )..add(const WalletLoadRequested());
    });

    Future<void> open(WidgetTester tester) async {
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
    }

    testWidgets('a preset chip fills the amount and a valid form submits then closes', (tester) async {
      await open(tester);
      await tester.tap(find.text('500'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), 'TRX-77');
      await tester.tap(find.text('إرسال طلب الشحن'));
      await _settle(tester);

      expect(repo.topUpCalls, 1);
      expect(repo.lastAmountCents, 50000);
      expect(repo.lastMethod, TopUpMethod.bankTransfer);
      expect(find.text('إرسال طلب الشحن'), findsNothing); // popped
    });

    testWidgets('an empty form shows validation and does not submit', (tester) async {
      await open(tester);
      await tester.tap(find.text('إرسال طلب الشحن'));
      await _settle(tester);
      expect(repo.topUpCalls, 0);
      expect(find.text('إرسال طلب الشحن'), findsOneWidget);
    });

    testWidgets('a failed submission keeps the screen open', (tester) async {
      repo.result = const Left(ServerFailure('رفض الخادم'));
      await open(tester);
      await tester.tap(find.text('100'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), 'TRX-1');
      await tester.tap(find.text('إرسال طلب الشحن'));
      await _settle(tester);
      expect(repo.topUpCalls, 1);
      expect(find.text('إرسال طلب الشحن'), findsOneWidget);
    });
  });
}
