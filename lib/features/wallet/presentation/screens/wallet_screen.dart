import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_motion_icons.dart';
import '../../../../core/presentation/foundation/seen_status.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/filters.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import '../widgets/ledger_row.dart';
import '../widgets/top_up_request_sheet.dart';
import '../widgets/wallet_card.dart';
import '../widgets/wallet_labels.dart';

/// Wallet & Ledger: balance summary, top-up entry point, and the
/// double-entry transaction feed.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, this.embedded = false});

  /// Shown as a tab of the dual-mode shell: no back button.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createWalletBloc()
        ..add(const WalletLoadRequested()),
      child: _WalletView(embedded: embedded),
    );
  }
}

class _WalletView extends StatelessWidget {
  const _WalletView({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SeenTopBar.inner(
        title: l10n.walletTitle,
        showBack: !embedded,
        trailing: SeenIconButton(
          icon: SeenIcons.refresh,
          semanticLabel: l10n.refreshAction,
          motionAsset: SeenMotionIcons.refresh,
          onPressed: () => context.read<WalletBloc>().add(const WalletLoadRequested()),
        ),
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          return switch (state) {
            WalletInitial() || WalletLoading() =>
              const Center(child: SeenLoader()),
            WalletFailure(:final message) => _ErrorView(message: message),
            WalletLoaded() => _LoadedView(state: state),
          };
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: SeenSpace.s3),
          SeenButton(
            label: l10n.retry,
            onPressed: () => context.read<WalletBloc>().add(const WalletLoadRequested()),
          ),
        ],
      ),
    );
  }
}

/// The ledger's credit/debit segment is a local, presentation-only refinement
/// over `WalletLoaded.filteredTransactions` (already `typeFilter`-filtered by
/// the Bloc) — it doesn't dispatch a Bloc event because `LedgerSide` isn't
/// the `TransactionType` the Bloc's existing filter operates on, and adding
/// a second server-side filter dimension is out of this reskin's scope.
enum _LedgerSideFilter { all, credits, debits }

class _LoadedView extends StatefulWidget {
  const _LoadedView({required this.state});

  final WalletLoaded state;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  _LedgerSideFilter _sideFilter = _LedgerSideFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final balance = widget.state.balance;
    final transactions = widget.state.filteredTransactions.where((t) => switch (_sideFilter) {
          _LedgerSideFilter.all => true,
          _LedgerSideFilter.credits => t.side == LedgerSide.credit,
          _LedgerSideFilter.debits => t.side == LedgerSide.debit,
        }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        context.read<WalletBloc>().add(const WalletLoadRequested());
        await context.read<WalletBloc>().stream.firstWhere((s) => s is! WalletLoading);
      },
      child: ListView(
        padding: const EdgeInsets.all(SeenSpace.s4),
        children: [
          SeenWalletCard(
            available: balance.availableCents / 100,
            hold: balance.holdCents / 100,
            creditLimit: balance.creditLimitCents / 100,
            onTopUp: () => showTopUpRequestSheet(context),
          ),
          SeenSectionHeader(title: l10n.walletTransactionsTitle),
          SeenSegmentChips(
            items: [
              SeenSegment(label: l10n.walletFilterAll),
              SeenSegment(label: l10n.walletLedgerFilterCredits),
              SeenSegment(label: l10n.walletLedgerFilterDebits),
            ],
            selectedIndex: _LedgerSideFilter.values.indexOf(_sideFilter),
            onSelected: (i) => setState(() => _sideFilter = _LedgerSideFilter.values[i]),
          ),
          const SizedBox(height: SeenSpace.s3),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text(l10n.walletEmptyTransactions)),
            )
          else
            SeenListGroup(children: [
              for (final transaction in transactions) _LedgerEntry(transaction: transaction),
            ]),
        ],
      ),
    );
  }
}

class _LedgerEntry extends StatelessWidget {
  const _LedgerEntry({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final credit = transaction.side == LedgerSide.credit;
    return SeenLedgerRow(
      type: credit ? SeenLedgerType.credit : SeenLedgerType.debit,
      title: WalletLabels.transactionType(l10n, transaction.type),
      reference: transaction.referenceId ?? '',
      time: SeenFormat.isolate(
          '${SeenFormat.date(transaction.createdAt)} ${SeenFormat.time(transaction.createdAt)}'),
      amount: transaction.amountCents / 100,
      // Approved is the expected resting state — only flag the exceptions.
      status: transaction.status == TransactionStatus.approved ? null : transaction.status.toSeenStatus,
    );
  }
}

extension on TransactionStatus {
  SeenStatus get toSeenStatus => switch (this) {
        TransactionStatus.approved => SeenStatus.approved,
        TransactionStatus.rejected => SeenStatus.rejected,
        TransactionStatus.pending || TransactionStatus.unknown => SeenStatus.pending,
      };
}
