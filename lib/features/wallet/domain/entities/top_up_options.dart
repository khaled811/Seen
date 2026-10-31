import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// What kind of Seen account money is paid into (`PaymentAccount.kind`).
enum PaymentAccountKind {
  walletApp('wallet_app'),
  bank('bank'),
  moneyTransfer('money_transfer'),
  other('other'),
  unknown('');

  const PaymentAccountKind(this.value);

  final String value;

  static PaymentAccountKind fromValue(String? value) {
    for (final kind in values) {
      if (kind.value == value) return kind;
    }
    return PaymentAccountKind.unknown;
  }
}

/// An account of Seen the agency pays into. Display data from the server; the
/// app never invents account details.
class PaymentAccount extends Equatable {
  const PaymentAccount({
    required this.id,
    required this.kind,
    required this.title,
    required this.holder,
    required this.bankName,
    required this.accountNumber,
    required this.currency,
    required this.instructions,
  });

  final String id;
  final PaymentAccountKind kind;
  final String title;
  final String holder;
  final String bankName;
  final String accountNumber;
  final String currency;
  final String instructions;

  @override
  List<Object?> get props => [id, kind, title, holder, bankName, accountNumber, currency, instructions];
}

/// One way to pay, with the kinds of account it can be paid into.
class TopUpMethodOption extends Equatable {
  const TopUpMethodOption({required this.method, required this.accountKinds});

  final TopUpMethod method;
  final List<PaymentAccountKind> accountKinds;

  @override
  List<Object?> get props => [method, accountKinds];
}

/// What the top-up screen needs (`portalTopUpOptions`): the methods, the
/// accounts to pay into (active ones), the minimum amount and whether this
/// person may request a top-up at all.
class TopUpOptions extends Equatable {
  const TopUpOptions({
    required this.currency,
    required this.methods,
    required this.accounts,
    required this.canRequest,
    this.minimumAmountCents,
    this.pendingCount = 0,
  });

  final String currency;
  final int? minimumAmountCents;
  final List<TopUpMethodOption> methods;
  final List<PaymentAccount> accounts;
  final bool canRequest;
  final int pendingCount;

  /// The accounts a [method] can be paid into, as the server maps them.
  List<PaymentAccount> accountsFor(TopUpMethod method) {
    final option = methods.where((m) => m.method == method).firstOrNull;
    if (option == null) return const [];
    return [
      for (final account in accounts)
        if (option.accountKinds.contains(account.kind)) account,
    ];
  }

  @override
  List<Object?> get props => [currency, minimumAmountCents, methods, accounts, canRequest, pendingCount];
}
