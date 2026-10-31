import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/top_up_options.dart';
import '../../domain/entities/wallet_balance.dart';
import '../../domain/entities/wallet_transaction.dart';

enum TopUpSubmissionStatus { idle, submitting, success, failure }

sealed class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

final class WalletInitial extends WalletState {
  const WalletInitial();
}

final class WalletLoading extends WalletState {
  const WalletLoading();
}

final class WalletFailure extends WalletState {
  const WalletFailure(this.message, {this.forbidden = false, this.failure});

  final String message;

  /// The underlying failure; the UI turns it into localized text.
  final Failure? failure;

  /// The server refused the wallet to this user (403): show the no-permission
  /// screen (Figma SYS-03) instead of a retry.
  final bool forbidden;

  @override
  List<Object?> get props => [message, forbidden, failure];
}

final class WalletLoaded extends WalletState {
  const WalletLoaded({
    required this.balance,
    required this.transactions,
    required this.typeFilter,
    this.topUpStatus = TopUpSubmissionStatus.idle,
    this.topUpError,
    this.submittedTopUp,
    this.refreshError,
    this.topUpFailure,
    this.refreshFailure,
    this.topUpOptions,
  });

  final WalletBalance balance;
  final List<WalletTransaction> transactions;
  final TransactionType? typeFilter;
  final TopUpSubmissionStatus topUpStatus;
  final String? topUpError;

  /// The request just created, for the confirmation screen (Figma WAL-05);
  /// cleared with the submission status.
  final WalletTransaction? submittedTopUp;

  /// A refresh failed but the numbers above are still the last known ones
  /// (Figma WAL-08 error banner).
  final String? refreshError;

  /// The failures behind [topUpError] / [refreshError] (shown localized).
  final Failure? topUpFailure;
  final Failure? refreshFailure;

  /// Where and how to pay; null while unknown (the load failed: the top-up
  /// screen then shows its "details unavailable" notes).
  final TopUpOptions? topUpOptions;

  List<WalletTransaction> get filteredTransactions => typeFilter == null
      ? transactions
      : transactions.where((t) => t.type == typeFilter).toList();

  WalletLoaded copyWith({
    WalletBalance? balance,
    List<WalletTransaction>? transactions,
    TransactionType? typeFilter,
    bool clearFilter = false,
    TopUpSubmissionStatus? topUpStatus,
    String? topUpError,
    bool clearTopUpError = false,
    bool clearSubmittedTopUp = false,
    WalletTransaction? submittedTopUp,
    String? refreshError,
    Failure? topUpFailure,
    Failure? refreshFailure,
    TopUpOptions? topUpOptions,
  }) =>
      WalletLoaded(
        balance: balance ?? this.balance,
        transactions: transactions ?? this.transactions,
        typeFilter: clearFilter ? null : (typeFilter ?? this.typeFilter),
        topUpStatus: topUpStatus ?? this.topUpStatus,
        topUpError: clearTopUpError ? null : (topUpError ?? this.topUpError),
        submittedTopUp: clearSubmittedTopUp ? null : (submittedTopUp ?? this.submittedTopUp),
        refreshError: refreshError ?? this.refreshError,
        topUpFailure: clearTopUpError ? null : (topUpFailure ?? this.topUpFailure),
        refreshFailure: refreshFailure ?? this.refreshFailure,
        topUpOptions: topUpOptions ?? this.topUpOptions,
      );

  @override
  List<Object?> get props =>
      [balance, transactions, typeFilter, topUpStatus, topUpError, submittedTopUp, refreshError, topUpFailure, refreshFailure, topUpOptions];
}
