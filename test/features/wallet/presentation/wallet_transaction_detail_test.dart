// Wallet transaction detail (Figma WAL-01), pending top-up (WAL-02) and
// rejected top-up (WAL-03). Arabic / RTL.

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
import 'package:seen_booking/features/wallet/data/models/wallet_transaction_dto.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:seen_booking/features/wallet/domain/repositories/top_up_cancellation_repository.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/cancel_top_up_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_transactions_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/request_top_up_usecase.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/top_up_cancel_cubit.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:seen_booking/features/wallet/presentation/screens/top_up_request_screen.dart';
import 'package:seen_booking/features/wallet/presentation/screens/wallet_transaction_detail_screen.dart';

final _at = DateTime(2026, 10, 14, 10, 45);

WalletTransaction _tx(
  TransactionType type,
  LedgerSide side,
  int cents, {
  TransactionStatus status = TransactionStatus.approved,
  String? ref,
  int? balanceAfter,
  LinkedRequest? request,
  TopUpInfo? topUp,
}) =>
    WalletTransaction(
      id: 't1',
      type: type,
      side: side,
      status: status,
      amountCents: cents,
      currency: WalletCurrency.usd,
      createdAt: _at,
      referenceId: ref,
      balanceAfterCents: balanceAfter,
      request: request,
      topUp: topUp,
    );

const _linked = LinkedRequest(id: 'r1', referenceId: 'SB-20489', serviceName: 'تأشيرة السعودية');

class _WalletRepo implements WalletRepository {
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
  }) async =>
      throw UnimplementedError();
}

class _CancelRepo implements TopUpCancellationRepository {
  _CancelRepo({this.failure});

  final Failure? failure;
  final cancelled = <String>[];

  @override
  Future<Either<Failure, WalletTransaction>> cancelTopUp(String transactionId) async {
    cancelled.add(transactionId);
    if (failure != null) return Left(failure!);
    return Right(_tx(TransactionType.topup, LedgerSide.credit, 50000));
  }
}

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

  Future<void> open(
    WidgetTester tester,
    WalletTransaction tx, {
    _CancelRepo? cancelRepo,
    void Function(BuildContext, LinkedRequest)? onViewRequest,
    WalletBloc? bloc,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = cancelRepo ?? _CancelRepo();
    Widget screen = WalletTransactionDetailScreen(
      transaction: tx,
      createCancelCubit: () => TopUpCancelCubit(cancelTopUp: CancelTopUpUseCase(repo)),
      onViewRequest: onViewRequest,
    );
    if (bloc != null) screen = BlocProvider.value(value: bloc, child: screen);
    // Pushed over a host route, as the wallet does: popping and the snackbar
    // after a cancellation need a screen underneath.
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => screen)),
          child: const Text('host-open'),
        ),
      ),
    )));
    await tester.tap(find.text('host-open'));
    await settle(tester);
  }

  group('wire mapping', () {
    test('balanceAfter, linked request and top-up info map from JSON', () {
      final tx = WalletTransactionDto.fromJson(const {
        'id': '1',
        'type': 'topup',
        'side': 'credit',
        'status': 'rejected',
        'amount': '1000.00',
        'createdAt': '2026-10-14T10:45:00Z',
        'balanceAfter': '1382.00',
        'request': {'id': 'r1', 'referenceId': 'SB-1', 'serviceName': 'x'},
        'topUp': {'method': 'bank_transfer', 'code': 'TU-1', 'rejectionReason': 'why'},
      }).toEntity();
      expect(tx.balanceAfterCents, 138200);
      expect(tx.request?.referenceId, 'SB-1');
      expect(tx.topUp?.method, TopUpMethod.bankTransfer);
      expect(tx.topUp?.rejectionReason, 'why');
    });
  });

  group('WAL-01 ledger detail', () {
    testWidgets('a hold shows the amount, rows, reference and the three-step path', (tester) async {
      LinkedRequest? opened;
      await open(
        tester,
        _tx(TransactionType.hold, LedgerSide.debit, 15000,
            ref: 'TX-88213', balanceAfter: 138200, request: _linked),
        onViewRequest: (_, r) => opened = r,
      );
      expect(find.text('تفاصيل العملية'), findsOneWidget);
      expect(find.text('حجز'), findsOneWidget); // chip
      expect(find.textContaining('150.00 USD'), findsOneWidget);
      expect(find.text('محجوز حتى إنجاز الطلب'), findsOneWidget);
      expect(find.text('حجز مبلغ'), findsOneWidget);
      expect(find.textContaining('SB-20489'), findsOneWidget);
      expect(find.textContaining('1,382.00 USD'), findsOneWidget);
      expect(find.textContaining('TX-88213'), findsOneWidget);
      expect(find.text('حُجز المبلغ'), findsOneWidget);
      expect(find.text('يُخصم عند إنجاز الطلب'), findsOneWidget);
      expect(find.text('أو يُعاد إن رُفض الطلب'), findsOneWidget);
      await tester.tap(find.text('عرض الطلب'));
      expect(opened?.id, 'r1');
    });

    testWidgets('copy puts the reference on the clipboard', (tester) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await open(tester, _tx(TransactionType.hold, LedgerSide.debit, 15000, ref: 'TX-88213'));
      await tester.tap(find.text('نسخ'));
      await settle(tester);
      expect(copied, 'TX-88213');
      expect(find.text('تم نسخ المرجع.'), findsOneWidget);
    });

    testWidgets('a deduction without a linked request has no action and no hold caption', (tester) async {
      await open(tester, _tx(TransactionType.finalDeduction, LedgerSide.debit, 27500, ref: 'TX-1'));
      expect(find.text('عرض الطلب'), findsNothing);
      expect(find.text('محجوز حتى إنجاز الطلب'), findsNothing);
      expect(find.text('خُصم المبلغ'), findsOneWidget);
    });

    testWidgets('a refund is shown as money in', (tester) async {
      await open(tester, _tx(TransactionType.refund, LedgerSide.credit, 15000));
      expect(find.textContaining('+150.00 USD'), findsOneWidget);
      expect(find.text('أُعيد المبلغ'), findsOneWidget);
    });
  });

  group('WAL-02 pending top-up', () {
    TopUpInfo info() => const TopUpInfo(
          method: TopUpMethod.bankTransfer,
          code: 'TU-2281',
          bankName: 'بنك الكريمي',
          transferReference: 'KR-77120934',
          receiptName: 'receipt_kuraimi.jpg',
          receiptUrl: 'mock://r.jpg',
        );

    testWidgets('shows the receipt, review path, method and transfer number', (tester) async {
      await open(
        tester,
        _tx(TransactionType.topup, LedgerSide.credit, 50000, status: TransactionStatus.pending, topUp: info()),
      );
      expect(find.text('طلب شحن'), findsOneWidget);
      expect(find.text('TU-2281'), findsOneWidget);
      expect(find.text('قيد المراجعة'), findsOneWidget);
      expect(find.textContaining('500.00 USD'), findsOneWidget);
      expect(find.text('receipt_kuraimi.jpg'), findsOneWidget);
      expect(find.text('عرض'), findsOneWidget);
      expect(find.text('أُرسل الطلب'), findsOneWidget);
      expect(find.text('قيد مراجعة المالية'), findsOneWidget);
      expect(find.text('يُضاف إلى رصيدك'), findsOneWidget);
      expect(find.textContaining('تحويل بنكي · بنك الكريمي'), findsOneWidget);
      expect(find.textContaining('KR-77120934'), findsOneWidget);
    });

    testWidgets('cancel asks first, then withdraws the request', (tester) async {
      final repo = _CancelRepo();
      await open(
        tester,
        _tx(TransactionType.topup, LedgerSide.credit, 50000, status: TransactionStatus.pending, topUp: info()),
        cancelRepo: repo,
      );
      await tester.tap(find.text('إلغاء طلب الشحن'));
      await settle(tester);
      expect(find.text('إلغاء طلب الشحن؟'), findsOneWidget);
      await tester.tap(find.text('تراجع'));
      await settle(tester);
      expect(repo.cancelled, isEmpty);

      await tester.tap(find.text('إلغاء طلب الشحن'));
      await settle(tester);
      await tester.tap(find.text('تأكيد الإلغاء'));
      await settle(tester);
      expect(repo.cancelled, ['t1']);
    });

    testWidgets('a request finance already decided says it cannot be cancelled', (tester) async {
      final repo = _CancelRepo(failure: const ServerFailure('no', code: 'NOT_CANCELLABLE'));
      await open(
        tester,
        _tx(TransactionType.topup, LedgerSide.credit, 50000, status: TransactionStatus.pending, topUp: info()),
        cancelRepo: repo,
      );
      await tester.tap(find.text('إلغاء طلب الشحن'));
      await settle(tester);
      await tester.tap(find.text('تأكيد الإلغاء'));
      await settle(tester);
      expect(find.text('راجعت المالية الطلب ولا يمكن إلغاؤه الآن.'), findsOneWidget);
    });
  });

  group('WAL-03 rejected top-up', () {
    final rejected = _tx(
      TransactionType.topup,
      LedgerSide.credit,
      100000,
      status: TransactionStatus.rejected,
      topUp: const TopUpInfo(
        method: TopUpMethod.cash,
        code: 'TU-2274',
        transferReference: 'REF-9',
        rejectionReason: 'المبلغ في الإيصال لا يطابق المبلغ المدخل.',
      ),
    );

    testWidgets('shows the reason, the reuse note and both actions', (tester) async {
      await open(tester, rejected);
      expect(find.text('TU-2274'), findsOneWidget);
      expect(find.text('مرفوض'), findsOneWidget);
      expect(find.textContaining('1,000.00 USD'), findsOneWidget);
      expect(find.text('سبب الرفض'), findsOneWidget);
      expect(find.text('المبلغ في الإيصال لا يطابق المبلغ المدخل.'), findsOneWidget);
      expect(find.text('سنعيد استخدام نفس البيانات، يمكنك تعديلها قبل الإرسال.'), findsOneWidget);
      expect(find.text('إعادة الإرسال'), findsOneWidget);
      expect(find.text('تواصل مع الدعم'), findsOneWidget);
    });

    testWidgets('without a reason it says so and points to support', (tester) async {
      await open(
        tester,
        _tx(TransactionType.topup, LedgerSide.credit, 100000, status: TransactionStatus.rejected),
      );
      expect(find.text('لم يُذكر سبب. تواصل مع الدعم لمعرفة التفاصيل.'), findsOneWidget);
    });

    testWidgets('resubmit opens the top-up form with the same details', (tester) async {
      final repo = _WalletRepo();
      final bloc = WalletBloc(
        getWalletBalanceUseCase: GetWalletBalanceUseCase(repo),
        getTransactionsUseCase: GetTransactionsUseCase(repo),
        requestTopUpUseCase: RequestTopUpUseCase(repo),
      );
      addTearDown(() => bloc.close().ignore());
      await open(tester, rejected, bloc: bloc);
      await tester.tap(find.text('إعادة الإرسال'));
      await settle(tester);
      expect(find.byType(TopUpRequestScreen), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '1000.00'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'REF-9'), findsOneWidget);
    });
  });
}
