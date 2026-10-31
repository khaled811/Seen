import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/idempotency_key.dart';
import '../../domain/entities/top_up_options.dart';
import '../../domain/entities/wallet_balance.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/usecases/get_top_up_options_usecase.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/get_wallet_balance_usecase.dart';
import '../../domain/usecases/request_top_up_usecase.dart';
import 'wallet_event.dart';
import 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    required GetWalletBalanceUseCase getWalletBalanceUseCase,
    required GetTransactionsUseCase getTransactionsUseCase,
    required RequestTopUpUseCase requestTopUpUseCase,
    GetTopUpOptionsUseCase? getTopUpOptionsUseCase,
    IdempotencyKeyRegistry? idempotencyKeys,
  })  : _getWalletBalanceUseCase = getWalletBalanceUseCase,
        _getTransactionsUseCase = getTransactionsUseCase,
        _requestTopUpUseCase = requestTopUpUseCase,
        _getTopUpOptionsUseCase = getTopUpOptionsUseCase,
        _idempotencyKeys = idempotencyKeys ?? IdempotencyKeyRegistry(),
        super(const WalletInitial()) {
    on<WalletLoadRequested>(_onLoadRequested, transformer: droppable());
    on<WalletTransactionTypeFilterChanged>(_onFilterChanged);
    on<WalletTopUpSubmitted>(_onTopUpSubmitted, transformer: droppable());
    on<WalletTopUpStatusCleared>(_onTopUpStatusCleared);
  }

  final GetWalletBalanceUseCase _getWalletBalanceUseCase;
  final GetTransactionsUseCase _getTransactionsUseCase;
  final RequestTopUpUseCase _requestTopUpUseCase;
  final GetTopUpOptionsUseCase? _getTopUpOptionsUseCase;

  /// One key per user action: a retry of the same top-up (same details) sends
  /// the same key, so a timeout can never create two requests.
  final IdempotencyKeyRegistry _idempotencyKeys;

  Future<void> _onLoadRequested(
    WalletLoadRequested event,
    Emitter<WalletState> emit,
  ) async {
    // A refresh that fails keeps the last known numbers (with a message) instead
    // of replacing them by an error screen.
    final previous = state is WalletLoaded ? state as WalletLoaded : null;
    emit(const WalletLoading());
    final result = await _fetchData();
    emit(
      result.match(
        (failure) => previous == null
            ? WalletFailure(failure.message, forbidden: failure is ForbiddenFailure, failure: failure)
            : previous.copyWith(refreshError: failure.message, refreshFailure: failure),
        (data) => WalletLoaded(
          balance: data.balance,
          transactions: data.transactions,
          typeFilter: null,
          // Keep what was known if the options could not be loaded this time.
          topUpOptions: data.options ?? previous?.topUpOptions,
        ),
      ),
    );
  }

  void _onFilterChanged(
    WalletTransactionTypeFilterChanged event,
    Emitter<WalletState> emit,
  ) {
    final current = state;
    if (current is! WalletLoaded) return;
    emit(current.copyWith(typeFilter: event.type, clearFilter: event.type == null));
  }

  Future<void> _onTopUpSubmitted(
    WalletTopUpSubmitted event,
    Emitter<WalletState> emit,
  ) async {
    final current = state;
    if (current is! WalletLoaded) return;

    emit(
      current.copyWith(
        topUpStatus: TopUpSubmissionStatus.submitting,
        clearTopUpError: true,
      ),
    );

    final key = _idempotencyKeys.keyFor(
      '${event.amountCents}|${event.method.value}|${event.referenceNumber}|${event.paymentAccountId}|${event.receiptFileId}',
    );
    final result = await _requestTopUpUseCase(
      amountCents: event.amountCents,
      method: event.method,
      referenceNumber: event.referenceNumber,
      idempotencyKey: key,
      paymentAccountId: event.paymentAccountId,
      receiptFileId: event.receiptFileId,
    );

    if (result case Left(:final value)) {
      final latest = state;
      if (latest is! WalletLoaded) return;
      emit(
        latest.copyWith(
          topUpStatus: TopUpSubmissionStatus.failure,
          topUpError: value.message,
          topUpFailure: value,
        ),
      );
      return;
    }

    // The request exists now: the next action gets a new key.
    _idempotencyKeys.settled();
    // Success: the backend is the source of truth for the resulting
    // balance/hold amounts and transaction list — refetch rather than
    // fabricate the update client-side.
    final created = (result as Right<Failure, WalletTransaction>).value;
    final refreshed = await _fetchData();
    emit(
      refreshed.match(
        // The top-up went through even if the refresh did not: say so, and keep
        // what was on screen with a refresh error instead of an error screen.
        (failure) => current.copyWith(
          topUpStatus: TopUpSubmissionStatus.success,
          submittedTopUp: created,
          refreshError: failure.message,
          refreshFailure: failure,
        ),
        (data) => WalletLoaded(
          balance: data.balance,
          transactions: data.transactions,
          typeFilter: current.typeFilter,
          topUpStatus: TopUpSubmissionStatus.success,
          submittedTopUp: created,
          topUpOptions: data.options ?? current.topUpOptions,
        ),
      ),
    );
  }

  void _onTopUpStatusCleared(
    WalletTopUpStatusCleared event,
    Emitter<WalletState> emit,
  ) {
    final current = state;
    if (current is! WalletLoaded) return;
    if (current.topUpStatus == TopUpSubmissionStatus.idle) return;
    emit(
      current.copyWith(
        topUpStatus: TopUpSubmissionStatus.idle,
        clearTopUpError: true,
        clearSubmittedTopUp: true,
      ),
    );
  }

  /// The balance and the ledger are required; the top-up options are a
  /// convenience (a failure there leaves the top-up screen without account
  /// details, it does not fail the wallet).
  Future<Either<Failure, ({WalletBalance balance, List<WalletTransaction> transactions, TopUpOptions? options})>>
      _fetchData() async {
    final balanceResult = await _getWalletBalanceUseCase();
    if (balanceResult case Left(:final value)) return Left(value);

    final transactionsResult = await _getTransactionsUseCase();
    if (transactionsResult case Left(:final value)) return Left(value);

    final optionsResult = await _getTopUpOptionsUseCase?.call();

    return Right((
      balance: (balanceResult as Right<Failure, WalletBalance>).value,
      transactions: (transactionsResult as Right<Failure, List<WalletTransaction>>).value,
      options: optionsResult?.toNullable(),
    ));
  }
}
