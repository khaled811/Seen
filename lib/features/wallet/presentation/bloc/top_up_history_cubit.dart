import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/usecases/get_transactions_usecase.dart';

enum TopUpHistoryStatus { loading, loaded, failure }

/// Figma WAL-04 filter chips (the order here is the data's, not the screen's).
enum TopUpHistoryFilter { all, pending, approved, rejected }

class TopUpHistoryState extends Equatable {
  const TopUpHistoryState({
    this.status = TopUpHistoryStatus.loading,
    this.items = const [],
    this.filter = TopUpHistoryFilter.all,
    this.hasMore = false,
    this.loadingMore = false,
    this.moreFailed = false,
    this.error,
    this.failure,
  });

  final TopUpHistoryStatus status;

  /// Every top-up loaded so far, newest first.
  final List<WalletTransaction> items;
  final TopUpHistoryFilter filter;
  final bool hasMore;
  final bool loadingMore;

  /// The last "load more" failed (the list stays; the link offers a retry).
  final bool moreFailed;
  final String? error;

  /// The failure behind [error] (shown localized).
  final Failure? failure;

  /// The server filters by type; the status chips narrow what was loaded.
  List<WalletTransaction> get visible => switch (filter) {
        TopUpHistoryFilter.all => items,
        TopUpHistoryFilter.pending => [for (final t in items) if (t.status == TransactionStatus.pending) t],
        TopUpHistoryFilter.approved => [for (final t in items) if (t.status == TransactionStatus.approved) t],
        TopUpHistoryFilter.rejected => [for (final t in items) if (t.status == TransactionStatus.rejected) t],
      };

  TopUpHistoryState copyWith({
    TopUpHistoryStatus? status,
    List<WalletTransaction>? items,
    TopUpHistoryFilter? filter,
    bool? hasMore,
    bool? loadingMore,
    bool? moreFailed,
    String? error,
    Failure? failure,
  }) =>
      TopUpHistoryState(
        status: status ?? this.status,
        items: items ?? this.items,
        filter: filter ?? this.filter,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        moreFailed: moreFailed ?? this.moreFailed,
        error: error ?? this.error,
        failure: failure ?? this.failure,
      );

  @override
  List<Object?> get props => [status, items, filter, hasMore, loadingMore, moreFailed, error, failure];
}

/// The agent's top-up requests, paged from the server's ledger filtered by the
/// `topup` type (Figma WAL-04).
class TopUpHistoryCubit extends Cubit<TopUpHistoryState> {
  TopUpHistoryCubit({required GetTransactionsUseCase getTransactions, this.pageSize = 20})
      : _get = getTransactions,
        super(const TopUpHistoryState());

  final GetTransactionsUseCase _get;
  final int pageSize;
  int _page = 1;

  Future<void> load() async {
    _page = 1;
    emit(TopUpHistoryState(filter: state.filter));
    final result = await _get(type: TransactionType.topup, page: 1, pageSize: pageSize);
    if (isClosed) return;
    result.match(
      (failure) => emit(TopUpHistoryState(
        status: TopUpHistoryStatus.failure,
        filter: state.filter,
        error: failure.message,
        failure: failure,
      )),
      (items) => emit(TopUpHistoryState(
        status: TopUpHistoryStatus.loaded,
        items: items,
        filter: state.filter,
        hasMore: items.length >= pageSize,
      )),
    );
  }

  Future<void> loadMore() async {
    if (state.status != TopUpHistoryStatus.loaded || !state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true, moreFailed: false));
    final result = await _get(type: TransactionType.topup, page: _page + 1, pageSize: pageSize);
    if (isClosed) return;
    result.match(
      (_) => emit(state.copyWith(loadingMore: false, moreFailed: true)),
      (items) {
        _page += 1;
        // A page can repeat rows when new top-ups arrive meanwhile: keep each id once.
        final known = {for (final t in state.items) t.id};
        emit(state.copyWith(
          items: [...state.items, for (final t in items) if (!known.contains(t.id)) t],
          hasMore: items.length >= pageSize,
          loadingMore: false,
        ));
      },
    );
  }

  void setFilter(TopUpHistoryFilter filter) => emit(state.copyWith(filter: filter));
}
