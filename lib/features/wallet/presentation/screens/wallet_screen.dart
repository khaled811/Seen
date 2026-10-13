import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/balance_card.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/segmented_control.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import '../widgets/ledger_row.dart';
import '../widgets/wallet_cards.dart';
import '../widgets/wallet_labels.dart';
import 'top_up_request_screen.dart';

/// Wallet & Ledger (Figma 11): balance card, top-up / statement actions, usage
/// split, pending top-ups and the double-entry transaction feed.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, this.embedded = false});

  /// Shown as a tab of the dual-mode shell: no back button.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createWalletBloc()..add(const WalletLoadRequested()),
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
      body: SeenScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              SeenScreenHeader(
                title: l10n.walletTitle,
                showBack: !embedded,
                trailing: SeenRoundIconButton(
                  icon: SeenIcons.refresh,
                  semanticLabel: l10n.refreshAction,
                  onPressed: () => context.read<WalletBloc>().add(const WalletLoadRequested()),
                ),
              ),
              Expanded(
                child: BlocBuilder<WalletBloc, WalletState>(
                  buildWhen: (p, c) => p.runtimeType != c.runtimeType || c is WalletLoaded || c is WalletFailure,
                  builder: (context, state) => switch (state) {
                    WalletInitial() || WalletLoading() => const Center(child: SeenLoader()),
                    WalletFailure(:final message) => _ErrorView(message: message),
                    WalletLoaded() => _LoadedView(state: state),
                  },
                ),
              ),
            ],
          ),
        ),
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
          SeenButton(label: l10n.retry, onPressed: () => context.read<WalletBloc>().add(const WalletLoadRequested())),
        ],
      ),
    );
  }
}

/// The ledger's credit/debit segment is a local, presentation-only refinement
/// over `WalletLoaded.filteredTransactions`; it does not dispatch a Bloc event
/// because `LedgerSide` is not the `TransactionType` the Bloc filters on.
enum _LedgerSideFilter { all, credits, debits }

class _LoadedView extends StatefulWidget {
  const _LoadedView({required this.state});

  final WalletLoaded state;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  _LedgerSideFilter _sideFilter = _LedgerSideFilter.all;

  void _openTopUp() => Navigator.of(context).push(TopUpRequestScreen.route(context.read<WalletBloc>()));

  void _openStatement() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => SeenSheet(
        title: l10n.walletStatementAction,
        child: Text(l10n.walletStatementSoonBody),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final balance = widget.state.balance;
    final all = widget.state.filteredTransactions;
    final pending = all.where((x) => x.type == TransactionType.topup && x.status == TransactionStatus.pending).toList();
    final transactions = all.where((x) => switch (_sideFilter) {
          _LedgerSideFilter.all => true,
          _LedgerSideFilter.credits => x.side == LedgerSide.credit,
          _LedgerSideFilter.debits => x.side == LedgerSide.debit,
        }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<WalletBloc>()..add(const WalletLoadRequested());
        await bloc.stream.firstWhere((s) => s is! WalletLoading);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, SeenSpace.s2, 20, 32),
        children: [
          SeenBalanceCard(
            available: balance.availableCents / 100,
            hold: balance.holdCents / 100,
            creditLimit: balance.creditLimitCents / 100,
            caption: l10n.homeBalanceCaption,
            holdLabel: l10n.homeHoldChip,
            creditLimitLabel: l10n.homeCreditLimitChip,
            showSemanticLabel: l10n.balanceHiddenLabel,
            hideSemanticLabel: l10n.balanceShownLabel,
          ),
          const SizedBox(height: SeenSpace.s3),
          Row(
            children: [
              Expanded(
                child: SeenButton(label: l10n.walletRequestTopUp, icon: SeenIcons.plus, expand: true, onPressed: _openTopUp),
              ),
              const SizedBox(width: SeenSpace.s3),
              Expanded(
                child: SeenButton.secondary(
                  label: l10n.walletStatementAction,
                  icon: SeenIcons.download,
                  expand: true,
                  onPressed: _openStatement,
                ),
              ),
            ],
          ),
          const SizedBox(height: SeenSpace.s4),
          SeenWalletUsageCard(
            available: balance.availableCents / 100,
            hold: balance.holdCents / 100,
            heldLabel: l10n.walletUsageHeldLabel,
            availableLabel: l10n.walletUsageAvailableLabel,
            heldValue: l10n.walletUsageHeldValue,
            availableValue: l10n.walletUsageAvailableValue,
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: SeenSpace.s3),
            for (final p in pending)
              Padding(
                padding: const EdgeInsets.only(bottom: SeenSpace.s2),
                child: SeenPendingTopUpCard(
                  title: l10n.walletPendingTopUpTitle(SeenFormat.usd(p.amountCents / 100)),
                  subtitle: l10n.walletPendingTopUpSent(SeenFormat.isolate(SeenFormat.date(p.createdAt))),
                  statusLabel: WalletLabels.transactionStatus(l10n, p.status),
                ),
              ),
          ],
          const SizedBox(height: SeenSpace.s4),
          Text(l10n.walletLedgerTitle, style: t.h2),
          const SizedBox(height: SeenSpace.s3),
          SeenSegmentedControl(
            labels: [l10n.walletFilterAll, l10n.walletLedgerFilterCredits, l10n.walletLedgerFilterDebits],
            selectedIndex: _LedgerSideFilter.values.indexOf(_sideFilter),
            onSelected: (i) => setState(() => _sideFilter = _LedgerSideFilter.values[i]),
          ),
          const SizedBox(height: SeenSpace.s3),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text(l10n.walletEmptyTransactions, style: t.body.copyWith(color: c.inkMuted))),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: const BorderRadius.all(SeenRadius.r22),
                border: Border.all(color: c.border),
                boxShadow: SeenShadows.card,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(SeenRadius.r22),
                child: Column(
                  children: [
                    for (var i = 0; i < transactions.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: c.border),
                      _LedgerEntry(transaction: transactions[i]),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LedgerEntry extends StatelessWidget {
  const _LedgerEntry({required this.transaction});

  final WalletTransaction transaction;

  static IconData? _icon(TransactionType type) => switch (type) {
        TransactionType.topup => SeenIcons.bank,
        TransactionType.hold => SeenIcons.lock,
        TransactionType.release || TransactionType.refund => SeenIcons.refresh,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final credit = transaction.side == LedgerSide.credit;
    final flagged = transaction.status != TransactionStatus.approved;
    return SeenLedgerRow(
      type: credit ? SeenLedgerType.credit : SeenLedgerType.debit,
      title: WalletLabels.transactionType(l10n, transaction.type),
      reference: transaction.referenceId ?? '',
      time: SeenFormat.isolate('${SeenFormat.date(transaction.createdAt)} ${SeenFormat.time(transaction.createdAt)}'),
      amount: transaction.amountCents / 100,
      icon: _icon(transaction.type),
      // Approved is the expected resting state — only flag the exceptions.
      status: flagged ? transaction.status.toChipStatus : null,
      statusLabel: flagged ? WalletLabels.transactionStatus(l10n, transaction.status) : null,
    );
  }
}

extension on TransactionStatus {
  SeenRequestStatus get toChipStatus => switch (this) {
        TransactionStatus.approved => SeenRequestStatus.completed,
        TransactionStatus.rejected => SeenRequestStatus.rejected,
        TransactionStatus.pending || TransactionStatus.unknown => SeenRequestStatus.underReview,
      };
}
