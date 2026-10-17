// Top-up history (Figma WAL-04): the agent's top-up requests, newest first, with
// status chips and "load more". Rows open the transaction detail (WAL-02 / 03).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/filters.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../bloc/top_up_history_cubit.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../widgets/wallet_labels.dart';
import 'wallet_transaction_detail_screen.dart';

const _gutter = 14.0;

/// Opens the history over the wallet's [WalletBloc] (taken from [context]); the
/// wallet reloads when a request is cancelled from here.
Future<void> openTopUpHistory(BuildContext context) {
  final bloc = context.read<WalletBloc>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(value: bloc, child: const TopUpHistoryScreen()),
    ),
  );
}

class TopUpHistoryScreen extends StatelessWidget {
  const TopUpHistoryScreen({super.key, this.createCubit});

  /// Test seam; defaults to the DI container.
  final TopUpHistoryCubit Function()? createCubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return BlocProvider(
      create: (_) => (createCubit ?? InjectionContainer.instance.createTopUpHistoryCubit)()..load(),
      child: Scaffold(
        backgroundColor: c.card,
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SeenScreenHeader(title: l10n.walletHistoryTitle),
                const Expanded(child: _Body()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  static const _order = [
    TopUpHistoryFilter.all,
    TopUpHistoryFilter.pending,
    TopUpHistoryFilter.approved,
    TopUpHistoryFilter.rejected,
  ];

  String _label(AppLocalizations l10n, SeenStrings s, TopUpHistoryFilter f) => switch (f) {
        TopUpHistoryFilter.all => l10n.requestsFilterAll,
        TopUpHistoryFilter.pending => l10n.requestDocStatusInReview,
        TopUpHistoryFilter.approved => s.approved,
        TopUpHistoryFilter.rejected => l10n.transactionStatusRejected,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    return BlocBuilder<TopUpHistoryCubit, TopUpHistoryState>(
      builder: (context, state) {
        final cubit = context.read<TopUpHistoryCubit>();
        if (state.status == TopUpHistoryStatus.loading) return const Center(child: SeenLoader());
        if (state.status == TopUpHistoryStatus.failure) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.error ?? l10n.error, textAlign: TextAlign.center),
                const SizedBox(height: SeenSpace.s3),
                SeenButton(label: l10n.retry, onPressed: cubit.load),
              ],
            ),
          );
        }
        final rows = state.visible;
        return RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, SeenSpace.s6),
            children: [
              SeenSegmentChips(
                padding: const EdgeInsets.symmetric(horizontal: _gutter),
                items: [for (final f in _order) SeenSegment(label: _label(l10n, s, f))],
                selectedIndex: _order.indexOf(state.filter),
                onSelected: (i) => cubit.setFilter(_order[i]),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(SeenSpace.s5),
                  child: SeenEmptyState(
                    iconAsset: SeenVectors.walletBank,
                    title: state.items.isEmpty ? l10n.walletHistoryEmpty : l10n.walletHistoryEmptyFilter,
                    message: state.items.isEmpty ? l10n.topUpScreenSubtitle : '',
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _gutter),
                  child: _List(rows: rows),
                ),
              if (state.hasMore) ...[
                const SizedBox(height: 12),
                Center(
                  child: state.loadingMore
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : SeenTextLink(
                          label: state.moreFailed ? l10n.walletHistoryLoadMoreRetry : l10n.walletHistoryLoadMore,
                          onTap: cubit.loadMore,
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.rows});

  final List<WalletTransaction> rows;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return DecoratedBox(
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
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.border),
              _Row(transaction: rows[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.transaction});

  final WalletTransaction transaction;

  Future<void> _open(BuildContext context) async {
    final wallet = context.read<WalletBloc>();
    final history = context.read<TopUpHistoryCubit>();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: wallet,
          child: WalletTransactionDetailScreen(transaction: transaction),
        ),
      ),
    );
    // A cancelled request left the ledger: refresh both lists.
    if (changed == true) {
      wallet.add(const WalletLoadRequested());
      history.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final method = transaction.topUp == null
        ? l10n.transactionTypeTopup
        : WalletLabels.topUpMethod(l10n, transaction.topUp!.method);
    final (chip, label) = switch (transaction.status) {
      TransactionStatus.approved => (SeenRequestStatus.completed, s.completed),
      TransactionStatus.rejected => (SeenRequestStatus.rejected, l10n.transactionStatusRejected),
      _ => (SeenRequestStatus.underReview, l10n.requestDocStatusInReview),
    };
    final amount = SeenFormat.usd(transaction.amountCents / 100);
    final meta = '$method · ${s.dayMonth(transaction.createdAt)}';
    return Semantics(
      button: true,
      container: true,
      label: '$amount $meta $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(11))),
                child: SizedBox(width: 36, height: 36, child: Center(child: SeenSvgIcon(SeenVectors.walletTxnBank, size: 20))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(amount, textDirection: TextDirection.ltr, style: t.label.copyWith(color: c.ink)),
                    Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SeenStatusChip(status: chip, label: label),
            ],
          ),
        ),
      ),
    );
  }
}
