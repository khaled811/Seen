import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/navigation/shell_tab_request.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/segmented_control.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../agents/presentation/screens/transfer_to_agent_screen.dart';
import '../../../system_status/presentation/widgets/access_denied_view.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import '../widgets/ledger_row.dart';
import '../widgets/statement_export_sheet.dart';
import '../widgets/wallet_balance_widgets.dart';
import '../widgets/wallet_cards.dart';
import '../widgets/wallet_labels.dart';
import 'top_up_history_screen.dart';
import 'top_up_request_screen.dart';
import 'wallet_transaction_detail_screen.dart';

/// Wallet & Ledger (Figma 11, node 18:434): title with a statement button,
/// the balance card, the held / available usage card, Top-up and Transfer
/// actions, a pending top-up, and the transaction ledger with a segmented
/// filter.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, this.embedded = false});

  /// Shown as a tab of the dual-mode shell. (Kept for the shell's API; the
  /// Figma header has no back button either way.)
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createWalletBloc()..add(const WalletLoadRequested()),
      child: const WalletView(),
    );
  }
}

/// The screen body, split from [WalletScreen] so tests can provide their own
/// [WalletBloc].
class WalletView extends StatelessWidget {
  const WalletView({super.key});

  void _openStatement(BuildContext context) => showStatementExportSheet(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Scaffold(
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.walletTitle, style: t.h1)),
                    Semantics(
                      button: true,
                      label: l10n.walletStatementAction,
                      excludeSemantics: true,
                      child: Material(
                        color: SeenBrand.violet10,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => _openStatement(context),
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(child: SeenSvgIcon(SeenVectors.accountDocument, size: 22, color: c.primary)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BlocBuilder<WalletBloc, WalletState>(
                  // A refresh keeps the numbers on screen (no skeleton over them).
                  buildWhen: (p, c) =>
                      !(p is WalletLoaded && c is WalletLoading) &&
                      (p.runtimeType != c.runtimeType || c is WalletLoaded || c is WalletFailure),
                  builder: (context, state) => switch (state) {
                    WalletInitial() || WalletLoading() => const WalletLoadingSkeleton(),
                    WalletFailure(forbidden: true) => AccessDeniedView(
                        area: 'wallet',
                        message: SeenStrings.of(context).forbiddenWallet,
                        onBack: () => ShellTabRequest.show(0),
                      ),
                    WalletFailure(:final message) => _ErrorView(message: message),
                    WalletLoaded() => _LoadedView(state: state, onStatement: () => _openStatement(context)),
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

/// The ledger's segment is a local, presentation-only refinement over
/// `WalletLoaded.filteredTransactions`; it does not dispatch a Bloc event
/// because `LedgerSide` is not the `TransactionType` the Bloc filters on.
/// Figma's order (start to end): All, Debits, Credits.
enum _LedgerSideFilter { all, debits, credits }

class _LoadedView extends StatefulWidget {
  const _LoadedView({required this.state, required this.onStatement});

  final WalletLoaded state;
  final VoidCallback onStatement;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  _LedgerSideFilter _sideFilter = _LedgerSideFilter.all;

  void _openTopUp() => Navigator.of(context).push(TopUpRequestScreen.route(context.read<WalletBloc>()));

  /// Opens a ledger entry (Figma WAL-01 / 02 / 03); a cancelled top-up changed
  /// the wallet, so the screen reloads when the detail reports it.
  Future<void> _openTransaction(WalletTransaction transaction) async {
    final bloc = context.read<WalletBloc>();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: WalletTransactionDetailScreen(transaction: transaction),
        ),
      ),
    );
    if (changed == true) bloc.add(const WalletLoadRequested());
  }

  Future<void> _openTransfer() async {
    final bloc = context.read<WalletBloc>();
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TransferToAgentScreen()),
    );
    // A transfer changed the balance and added a ledger row.
    if (done == true) bloc.add(const WalletLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
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
    const gap = SizedBox(height: 18);

    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<WalletBloc>()..add(const WalletLoadRequested());
        await bloc.stream.firstWhere((x) => x is! WalletLoading);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          // The last refresh failed: the numbers below are the last known ones.
          if (widget.state.refreshError != null) ...[
            SeenInlineBanner(
              tone: SeenBannerTone.error,
              message: l10n.walletBalanceRefreshFailed(SeenFormat.usd(balance.availableCents / 100)),
              actionLabel: l10n.walletBalanceRetry,
              onAction: () => context.read<WalletBloc>().add(const WalletLoadRequested()),
            ),
            gap,
          ],
          if (balance.isOverLimit) ...[SeenOverLimitCard(balance: balance), gap],
          SeenBalanceBreakdownCard(balance: balance),
          gap,
          // Top-up leads (start edge), Transfer trails, as drawn.
          Row(
            children: [
              Expanded(child: SeenButton(label: l10n.topUpScreenTitle, expand: true, onPressed: _openTopUp)),
              const SizedBox(width: 8),
              Expanded(
                child: SeenButton.secondary(label: l10n.walletTransferToAgent, expand: true, onPressed: _openTransfer),
              ),
            ],
          ),
          for (final p in pending) ...[
            gap,
            SeenPendingTopUpCard(
              title: l10n.walletPendingTopUpTitle(SeenFormat.usd(p.amountCents / 100)),
              subtitle: l10n.walletPendingTopUpSent(s.dayMonth(p.createdAt)),
              statusLabel: WalletLabels.transactionStatus(l10n, p.status),
              onTap: () => _openTransaction(p),
            ),
          ],
          gap,
          SeenBalanceLegendCard(showCredit: balance.creditLimitCents > 0),
          gap,
          Row(
            children: [
              Expanded(child: Text(l10n.walletLedgerTitle, style: t.h2)),
              SeenTextLink(label: l10n.walletHistoryLink, onTap: () => openTopUpHistory(context)),
              const SizedBox(width: 12),
              SeenTextLink(label: l10n.walletStatementAction, onTap: widget.onStatement),
            ],
          ),
          gap,
          SeenSegmentedControl(
            labels: [l10n.walletFilterAll, l10n.walletLedgerFilterDebits, l10n.walletLedgerFilterCredits],
            selectedIndex: _LedgerSideFilter.values.indexOf(_sideFilter),
            onSelected: (i) => setState(() => _sideFilter = _LedgerSideFilter.values[i]),
          ),
          gap,
          if (transactions.isEmpty)
            // Figma WAL-09: an illustration, what is missing, and the way out.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SeenEmptyState(
                iconAsset: SeenVectors.walletIcon,
                title: switch (_sideFilter) {
                  _LedgerSideFilter.all => l10n.walletEmptyAllTitle,
                  _LedgerSideFilter.credits => l10n.walletEmptyCreditsTitle,
                  _LedgerSideFilter.debits => l10n.walletEmptyDebitsTitle,
                },
                message: l10n.walletEmptyMessage,
                actionLabel: l10n.topUpScreenTitle,
                onAction: _openTopUp,
              ),
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
                      _LedgerEntry(transaction: transactions[i], onTap: () => _openTransaction(transactions[i])),
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
  const _LedgerEntry({required this.transaction, required this.onTap});

  final WalletTransaction transaction;
  final VoidCallback onTap;

  /// Figma tiles: a bank for top-ups, the transfer arrows for money coming
  /// back (refund / release), the request glyph for charges. The API does not
  /// say which service a charge belongs to, so there is no per-service icon.
  static String _icon(WalletTransaction x) => switch (x.type) {
        TransactionType.topup => SeenVectors.walletTxnBank,
        TransactionType.refund || TransactionType.release => SeenVectors.walletTxnTransfer,
        _ => SeenVectors.iconRequests,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final credit = transaction.side == LedgerSide.credit;
    final flagged = transaction.status != TransactionStatus.approved;
    // Figma WAL-10: holds, deductions and returns say what happened to the money.
    final (SeenRequestStatus, String)? semantic = transaction.status == TransactionStatus.rejected
        ? null
        : switch (transaction.type) {
            TransactionType.hold => (SeenRequestStatus.actionRequired, l10n.walletChipHeld),
            TransactionType.finalDeduction => (SeenRequestStatus.rejected, l10n.walletChipDeducted),
            TransactionType.refund || TransactionType.release => (SeenRequestStatus.completed, l10n.walletChipReturned),
            _ => null,
          };
    final ref = transaction.referenceId;
    final label = WalletLabels.transactionType(l10n, transaction.type);
    return SeenLedgerRow(
      type: credit ? SeenLedgerType.credit : SeenLedgerType.debit,
      title: ref == null || ref.isEmpty ? label : '$label · ${SeenFormat.isolate(ref)}',
      meta: '${s.dayMonth(transaction.createdAt)} · ${SeenFormat.time(transaction.createdAt)}',
      amount: transaction.amountCents / 100,
      iconAsset: _icon(transaction),
      onTap: onTap,
      // Approved is the expected resting state — only flag the exceptions.
      statusChip: semantic != null
          ? SeenStatusChip(status: semantic.$1, label: semantic.$2)
          : flagged
          ? SeenStatusChip(
              status: transaction.status.toChipStatus,
              label: WalletLabels.transactionStatus(l10n, transaction.status),
            )
          : null,
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
