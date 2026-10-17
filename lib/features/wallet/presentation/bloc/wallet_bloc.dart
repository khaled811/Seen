import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/wallet_balance.dart';
import '../../domain/entities/wallet_transaction.dart';
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
  })  : _getWalletBalanceUseCase = getWalletBalanceUseCase,
        _getTransactionsUseCase = getTransactionsUseCase,
        _requestTopUpUseCase = requestTopUpUseCase,
        super(const WalletInitial()) {
    on<WalletLoadRequested>(_onLoadRequested, transformer: droppable());
    on<WalletTransactionTypeFilterChanged>(_onFilterChanged);
    on<WalletTopUpSubmitted>(_onTopUpSubmitted, transformer: droppable());
    on<WalletTopUpStatusCleared>(_onTopUpStatusCleared);
  }

  final GetWalletBalanceUseCase _getWalletBalanceUseCase;
  final GetTransactionsUseCase _getTransactionsUseCase;
  final RequestTopUpUseCase _requestTopUpUseCase;

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
            ? WalletFailure(failure.message, forbidden: failure is ForbiddenFailure)
            : previous.copyWith(refreshError: failure.message),
        (data) => WalletLoaded(
          balance: data.$1,
          transactions: data.$2,
          typeFilter: null,
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

    final result = await _requestTopUpUseCase(
      amountCents: event.amountCents,
      method: event.method,
      referenceNumber: event.referenceNumber,
      notes: event.notes,
    );

    if (result case Left(:final value)) {
      final latest = state;
      if (latest is! WalletLoaded) return;
      emit(
        latest.copyWith(
          topUpStatus: TopUpSubmissionStatus.failure,
          topUpError: value.message,
        ),
      );
      return;
    }

    // Success: the backend is the source of truth for the resulting
    // balance/hold amounts and transaction list — refetch rather than
    // fabricate the update client-side.
    final created = (result as Right<Failure, WalletTransaction>).value;
    final refreshed = await _fetchData();
    emit(
      refreshed.match(
        (failure) => WalletFailure(failure.message, forbidden: failure is ForbiddenFailure),
        (data) => WalletLoaded(
          balance: data.$1,
          transactions: data.$2,
          typeFilter: current.typeFilter,
          topUpStatus: TopUpSubmissionStatus.success,
          submittedTopUp: created,
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

  Future<Either<Failure, (WalletBalance, List<WalletTransaction>)>> _fetchData() async {
    final balanceResult = await _getWalletBalanceUseCase();
    if (balanceResult case Left(:final value)) return Left(value);

    final transactionsResult = await _getTransactionsUseCase();
    if (transactionsResult case Left(:final value)) return Left(value);

    final balance = (balanceResult as Right<Failure, WalletBalance>).value;
    final transactions =
        (transactionsResult as Right<Failure, List<WalletTransaction>>).value;
    return Right((balance, transactions));
  }
}
