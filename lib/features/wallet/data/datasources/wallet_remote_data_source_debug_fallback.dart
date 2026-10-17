import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/statement.dart';
import '../models/statement_file_dto.dart';
import '../models/wallet_balance_dto.dart';
import '../models/wallet_transaction_dto.dart';
import 'wallet_remote_data_source.dart';

/// DEBUG ONLY — decorates a real [WalletRemoteDataSource] and, only when a
/// real call fails **and** the app is running in a debug build, substitutes
/// canned demo data instead. Lets the Wallet screen, ledger list, and
/// top-up sheet be previewed end-to-end before the backend exists.
///
/// `kDebugMode` is a compile-time constant, so in a release build every
/// fallback branch below is dead-code-eliminated — this can never surface
/// fake financial data to a real user. It falls back on failure rather
/// than unconditionally in debug, so a real backend reachable from a debug
/// build is still exercised normally, not masked by demo data.
class DebugFallbackWalletRemoteDataSource implements WalletRemoteDataSource {
  DebugFallbackWalletRemoteDataSource(this._real);

  final WalletRemoteDataSource _real;

  /// In-memory only — reset on app restart, never touches real persistence.
  /// Mutable so a debug-mode top-up submission shows up in the ledger on
  /// the next fetch, making the demo flow feel real end-to-end.
  final List<WalletTransactionDto> _mockTransactions = _seedTransactions(DateTime.now());

  @override
  Future<Either<Failure, StatementFileDto>> exportStatement({
    required DateTime from,
    required DateTime to,
    required StatementFormat format,
  }) async {
    final result = await _real.exportStatement(from: from, to: to, format: format);
    if (!(kDebugMode && result.isLeft())) return result;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // The debug document source serves a sample PDF for any mock:// link.
    return Right(StatementFileDto(url: 'mock://statements/statement.pdf', fileName: 'statement.${format.extension}'));
  }

  @override
  Future<Either<Failure, WalletTransactionDto>> cancelTopUp(String transactionId) async {
    final result = await _real.cancelTopUp(transactionId);
    if (!(kDebugMode && result.isLeft())) return result;
    final index = _mockTransactions.indexWhere((t) => t.id == transactionId);
    if (index < 0) return const Left(ServerFailure('Top-up not found.'));
    // Demo: only a request finance has not decided yet can be withdrawn.
    if (_mockTransactions[index].status != TransactionStatus.pending.value) {
      return const Left(ServerFailure('Not cancellable', code: 'NOT_CANCELLABLE'));
    }
    return Right(_mockTransactions.removeAt(index));
  }

  @override
  Future<Either<Failure, WalletBalanceDto>> getBalance() async {
    final result = await _real.getBalance();
    if (kDebugMode && result.isLeft()) return const Right(_mockBalance);
    return result;
  }

  @override
  Future<Either<Failure, List<WalletTransactionDto>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await _real.getTransactions(
      type: type,
      from: from,
      to: to,
      page: page,
      pageSize: pageSize,
    );
    if (kDebugMode && result.isLeft()) {
      return Right(List.unmodifiable(_mockTransactions));
    }
    return result;
  }

  @override
  Future<Either<Failure, WalletTransactionDto>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    String? notes,
  }) async {
    final result = await _real.requestTopUp(
      amountCents: amountCents,
      method: method,
      referenceNumber: referenceNumber,
      notes: notes,
    );
    if (kDebugMode && result.isLeft()) {
      final mock = WalletTransactionDto(
        id: 'debug-topup-${_mockTransactions.length + 1}',
        type: TransactionType.topup.value,
        side: LedgerSide.credit.value,
        status: TransactionStatus.pending.value,
        amount: MoneyParser.decimalStringFromCents(amountCents),
        currency: WalletCurrency.usd.value,
        createdAt: DateTime.now(),
        referenceId: referenceNumber,
        notes: notes,
      );
      _mockTransactions.insert(0, mock);
      return Right(mock);
    }
    return result;
  }
}

const _mockBalance = WalletBalanceDto(
  availableAmount: '5420.00',
  holdAmount: '350.00',
  creditLimitAmount: '1000.00',
  creditUsedAmount: '540.00',
  currency: 'USD',
);

List<WalletTransactionDto> _seedTransactions(DateTime now) => [
      WalletTransactionDto(
        id: 'debug-txn-1',
        type: TransactionType.topup.value,
        side: LedgerSide.credit.value,
        status: TransactionStatus.approved.value,
        amount: '2000.00',
        currency: WalletCurrency.usd.value,
        createdAt: now.subtract(const Duration(days: 6)),
        referenceId: 'TXN-1001',
        notes: 'Bank transfer top-up',
        balanceAfter: '5420.00',
        topUp: const TopUpInfoDto(
          method: 'bank_transfer',
          code: 'TU-2270',
          bankName: 'بنك الكريمي',
          transferReference: 'KR-77100112',
        ),
      ),
      WalletTransactionDto(
        id: 'debug-txn-2',
        type: TransactionType.topup.value,
        side: LedgerSide.credit.value,
        status: TransactionStatus.pending.value,
        amount: '1500.00',
        currency: WalletCurrency.usd.value,
        createdAt: now.subtract(const Duration(days: 3)),
        referenceId: 'TXN-1002',
        notes: 'Exchange house top-up, awaiting approval',
        topUp: const TopUpInfoDto(
          method: 'bank_transfer',
          code: 'TU-2281',
          bankName: 'بنك الكريمي',
          transferReference: 'KR-77120934',
          receiptName: 'receipt_kuraimi.jpg',
          receiptUrl: 'mock://documents/receipt_kuraimi.jpg',
        ),
      ),
      WalletTransactionDto(
        id: 'debug-txn-6',
        type: TransactionType.topup.value,
        side: LedgerSide.credit.value,
        status: TransactionStatus.rejected.value,
        amount: '1000.00',
        currency: WalletCurrency.usd.value,
        createdAt: now.subtract(const Duration(days: 4)),
        referenceId: 'TXN-1006',
        topUp: const TopUpInfoDto(
          method: 'bank_transfer',
          code: 'TU-2274',
          bankName: 'بنك الكريمي',
          transferReference: 'KR-77098765',
          rejectionReason: 'المبلغ في الإيصال (900.00 USD) لا يطابق المبلغ المدخل. أعد الإرسال بالمبلغ الصحيح أو أرفق الإيصال الصحيح.',
        ),
      ),
      WalletTransactionDto(
        id: 'debug-txn-3',
        type: TransactionType.finalDeduction.value,
        side: LedgerSide.debit.value,
        status: TransactionStatus.approved.value,
        amount: '450.00',
        currency: WalletCurrency.usd.value,
        createdAt: now.subtract(const Duration(days: 2)),
        referenceId: 'TX-88201',
        notes: 'Egypt tourist visa — Ahmed Hassan',
        balanceAfter: '3420.00',
        request: const LinkedRequestDto(id: 'req-3', referenceId: 'SB-1003', serviceName: 'Egypt National Security Approval'),
      ),
      WalletTransactionDto(
        id: 'debug-txn-4',
        type: TransactionType.finalDeduction.value,
        side: LedgerSide.debit.value,
        status: TransactionStatus.approved.value,
        amount: '275.00',
        currency: WalletCurrency.usd.value,
        createdAt: now.subtract(const Duration(days: 1)),
        referenceId: 'TX-88214',
        notes: 'Egypt tourist visa — Sara Ali',
        balanceAfter: '3145.00',
        request: const LinkedRequestDto(id: 'req-2', referenceId: 'SB-1002', serviceName: 'Egypt Military Intelligence Approval'),
      ),
      WalletTransactionDto(
        id: 'debug-txn-5',
        type: TransactionType.hold.value,
        side: LedgerSide.debit.value,
        status: TransactionStatus.pending.value,
        amount: '350.00',
        currency: WalletCurrency.usd.value,
        createdAt: now,
        referenceId: 'TX-88213',
        notes: 'Egypt visa request under review',
        balanceAfter: '5420.00',
        request: const LinkedRequestDto(id: 'req-9', referenceId: 'SB-1009', serviceName: 'حجز طيران'),
      ),
    ];
