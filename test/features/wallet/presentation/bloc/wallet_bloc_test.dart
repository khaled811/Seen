import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_transactions_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';
import 'package:seen_booking/features/wallet/domain/usecases/request_top_up_usecase.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:seen_booking/features/wallet/presentation/bloc/wallet_state.dart';

const _balance = WalletBalance(
  availableCents: 100000,
  holdCents: 5000,
  creditLimitCents: 500000,
  currency: WalletCurrency.usd,
);

final _transaction = WalletTransaction(
  id: 't1',
  type: TransactionType.topup,
  side: LedgerSide.credit,
  status: TransactionStatus.pending,
  amountCents: 20000,
  currency: WalletCurrency.usd,
  createdAt: DateTime(2026, 1, 1),
  referenceId: 'REF-1',
);

/// Hand-rolled fake — the interface is small enough that a mocking package
/// isn't worth the extra dev dependency.
class _FakeWalletRepository implements WalletRepository {
  Either<Failure, WalletBalance> balanceResult = const Right(_balance);
  Either<Failure, List<WalletTransaction>> transactionsResult = Right([_transaction]);
  Either<Failure, WalletTransaction> topUpResult = Right(_transaction);

  int getBalanceCalls = 0;
  int getTransactionsCalls = 0;
  int requestTopUpCalls = 0;

  @override
  Future<Either<Failure, WalletBalance>> getBalance() async {
    getBalanceCalls++;
    return balanceResult;
  }

  @override
  Future<Either<Failure, List<WalletTransaction>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    getTransactionsCalls++;
    return transactionsResult;
  }

  @override
  Future<Either<Failure, WalletTransaction>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    String? notes,
  }) async {
    requestTopUpCalls++;
    return topUpResult;
  }
}

void main() {
  late _FakeWalletRepository repository;
  late WalletBloc bloc;

  setUp(() {
    repository = _FakeWalletRepository();
    bloc = WalletBloc(
      getWalletBalanceUseCase: GetWalletBalanceUseCase(repository),
      getTransactionsUseCase: GetTransactionsUseCase(repository),
      requestTopUpUseCase: RequestTopUpUseCase(repository),
    );
  });

  tearDown(() => bloc.close());

  test('initial state is WalletInitial', () {
    expect(bloc.state, const WalletInitial());
  });

  group('WalletLoadRequested', () {
    test('emits [Loading, Loaded] on success', () async {
      final states = <WalletState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(const WalletLoadRequested());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);
      await subscription.cancel();

      expect(states, [
        const WalletLoading(),
        WalletLoaded(
          balance: _balance,
          transactions: [_transaction],
          typeFilter: null,
        ),
      ]);
    });

    test('emits [Loading, Failure] when the balance call fails', () async {
      repository.balanceResult = const Left(ServerFailure('boom'));
      final states = <WalletState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(const WalletLoadRequested());
      await bloc.stream.firstWhere((s) => s is WalletFailure);
      await subscription.cancel();

      expect(states, [const WalletLoading(), const WalletFailure('boom')]);
    });
  });

  group('WalletTransactionTypeFilterChanged', () {
    test('filters the already-loaded transactions without refetching', () async {
      bloc.add(const WalletLoadRequested());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);
      expect(repository.getTransactionsCalls, 1);

      bloc.add(const WalletTransactionTypeFilterChanged(TransactionType.hold));
      final filtered = await bloc.stream.first as WalletLoaded;

      expect(filtered.typeFilter, TransactionType.hold);
      expect(filtered.filteredTransactions, isEmpty); // _transaction is a topup
      expect(repository.getTransactionsCalls, 1); // no extra network call
    });
  });

  group('WalletTopUpSubmitted', () {
    test('submits, then refetches, ending in success status', () async {
      bloc.add(const WalletLoadRequested());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);

      bloc.add(
        const WalletTopUpSubmitted(
          amountCents: 5000,
          method: TopUpMethod.bankTransfer,
          referenceNumber: 'REF-2',
        ),
      );

      final submitting = await bloc.stream.first as WalletLoaded;
      expect(submitting.topUpStatus, TopUpSubmissionStatus.submitting);

      final success = await bloc.stream.firstWhere(
        (s) => s is WalletLoaded && s.topUpStatus == TopUpSubmissionStatus.success,
      ) as WalletLoaded;
      expect(success.topUpStatus, TopUpSubmissionStatus.success);
      expect(repository.requestTopUpCalls, 1);
      expect(repository.getBalanceCalls, 2); // initial load + post-submit refresh
    });

    test('surfaces a failure without touching the loaded data', () async {
      bloc.add(const WalletLoadRequested());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);

      repository.topUpResult = const Left(ServerFailure('rejected'));
      bloc.add(
        const WalletTopUpSubmitted(
          amountCents: 5000,
          method: TopUpMethod.cash,
          referenceNumber: 'REF-3',
        ),
      );

      await bloc.stream.firstWhere((s) => s is WalletLoaded && s.topUpStatus == TopUpSubmissionStatus.submitting);
      final failed = await bloc.stream.firstWhere(
        (s) => s is WalletLoaded && s.topUpStatus == TopUpSubmissionStatus.failure,
      ) as WalletLoaded;

      expect(failed.topUpError, 'rejected');
      expect(failed.balance, _balance); // untouched — no refetch on failure
    });
  });
}
