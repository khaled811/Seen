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
  });

  final WalletBalance balance;
  final List<WalletTransaction> transactions;
  final TransactionType? typeFilter;
  final TopUpSubmissionStatus topUpStatus;
  final String? topUpError;

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
  }) =>
      WalletLoaded(
        balance: balance ?? this.balance,
        transactions: transactions ?? this.transactions,
        typeFilter: clearFilter ? null : (typeFilter ?? this.typeFilter),
        topUpStatus: topUpStatus ?? this.topUpStatus,
        topUpError: clearTopUpError ? null : (topUpError ?? this.topUpError),
      );

  @override
  List<Object?> get props =>
      [balance, transactions, typeFilter, topUpStatus, topUpError];
}
