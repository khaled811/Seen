import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
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
  const WalletFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
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
    String? refreshError,
  }) =>
      WalletLoaded(
        balance: balance ?? this.balance,
        transactions: transactions ?? this.transactions,
        typeFilter: clearFilter ? null : (typeFilter ?? this.typeFilter),
        topUpStatus: topUpStatus ?? this.topUpStatus,
        topUpError: clearTopUpError ? null : (topUpError ?? this.topUpError),
        submittedTopUp: clearSubmittedTopUp ? null : submittedTopUp,
        refreshError: refreshError ?? this.refreshError,
      );

  @override
  List<Object?> get props =>
      [balance, transactions, typeFilter, topUpStatus, topUpError, submittedTopUp, refreshError];
}
