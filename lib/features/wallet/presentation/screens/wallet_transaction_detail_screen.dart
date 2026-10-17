// Wallet transaction detail (Figma WAL-01) and the two top-up variants:
// pending (WAL-02, receipt, review timeline, cancel) and rejected (WAL-03,
// reason, resubmit). One screen, three bodies chosen by the transaction.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../requests/presentation/bloc/requests_bloc.dart';
import '../../../requests/presentation/bloc/requests_event.dart';
import '../../../requests/presentation/bloc/requests_state.dart';
import '../../../requests/presentation/screens/request_detail_screen.dart';
import '../../../requests/presentation/screens/request_document_viewer_screen.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../bloc/top_up_cancel_cubit.dart';
import '../bloc/wallet_bloc.dart';
import '../widgets/wallet_labels.dart';
import 'top_up_request_screen.dart';

const _gutter = 20.0;

enum _Variant { ledger, topUpPending, topUpRejected }

/// Opens [LinkedRequest] in the request tracking screen. Loads the request list
/// first (the screen's bloc needs it), then the request itself.
Future<void> openLinkedRequest(BuildContext context, LinkedRequest request) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => InjectionContainer.instance.createRequestsBloc()..add(const RequestsLoadRequested()),
        child: BlocListener<RequestsBloc, RequestsState>(
          listenWhen: (previous, current) => current is RequestsLoaded && previous is! RequestsLoaded,
          listener: (context, _) => context.read<RequestsBloc>().add(RequestDetailRequested(request.id)),
          child: const RequestDetailScreen(),
        ),
      ),
    ),
  );
}

class WalletTransactionDetailScreen extends StatelessWidget {
  const WalletTransactionDetailScreen({
    super.key,
    required this.transaction,
    this.createCancelCubit,
    this.onViewRequest,
  });

  final WalletTransaction transaction;

  /// Test seams: the cancel cubit (defaults to the DI container) and how the
  /// linked request is opened (defaults to [openLinkedRequest]).
  final TopUpCancelCubit Function()? createCancelCubit;
  final void Function(BuildContext context, LinkedRequest request)? onViewRequest;

  _Variant get _variant {
    if (transaction.type == TransactionType.topup) {
      if (transaction.status == TransactionStatus.pending) return _Variant.topUpPending;
      if (transaction.status == TransactionStatus.rejected) return _Variant.topUpRejected;
    }
    return _Variant.ledger;
  }

  @override
  Widget build(BuildContext context) {
    final variant = _variant;
    final c = SeenColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isTopUp = variant != _Variant.ledger;
    final body = switch (variant) {
      _Variant.ledger => _LedgerBody(transaction: transaction),
      _Variant.topUpPending => _TopUpPendingBody(transaction: transaction),
      _Variant.topUpRejected => _TopUpRejectedBody(transaction: transaction),
    };
    final screen = Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SeenScreenHeader(
                title: isTopUp ? l10n.walletTopUpDetailTitle : l10n.walletTxnTitle,
                subtitle: isTopUp ? transaction.topUp?.code : null,
              ),
              Expanded(child: body),
              _Actions(
                transaction: transaction,
                variant: variant,
                onViewRequest: onViewRequest ?? openLinkedRequest,
              ),
            ],
          ),
        ),
      ),
    );
    if (variant != _Variant.topUpPending) return screen;
    return BlocProvider(
      create: (_) => (createCancelCubit ?? InjectionContainer.instance.createTopUpCancelCubit)(),
      child: BlocListener<TopUpCancelCubit, TopUpCancelState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          final message = switch (state.status) {
            TopUpCancelStatus.success => l10n.walletTopUpCancelled,
            TopUpCancelStatus.notCancellable => l10n.walletTopUpNotCancellable,
            TopUpCancelStatus.failure => state.message ?? l10n.error,
            _ => null,
          };
          if (message == null) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          // The wallet reloads on `true`: a cancelled request leaves the ledger,
          // and one finance already decided shows its new state.
          if (state.status == TopUpCancelStatus.success || state.status == TopUpCancelStatus.notCancellable) {
            Navigator.of(context).pop(true);
          }
        },
        child: screen,
      ),
    );
  }
}

// ---------------------------------------------------------------- actions

class _Actions extends StatelessWidget {
  const _Actions({required this.transaction, required this.variant, required this.onViewRequest});

  final WalletTransaction transaction;
  final _Variant variant;
  final void Function(BuildContext context, LinkedRequest request) onViewRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (variant) {
      case _Variant.ledger:
        final request = transaction.request;
        if (request == null) return const SizedBox.shrink();
        return SeenActionBar(
          actions: [
            SeenButton.secondary(
              label: l10n.walletTxnViewRequest,
              expand: true,
              onPressed: () => onViewRequest(context, request),
            ),
          ],
        );
      case _Variant.topUpPending:
        return BlocBuilder<TopUpCancelCubit, TopUpCancelState>(
          builder: (context, state) {
            final busy = state.status == TopUpCancelStatus.submitting;
            return SeenActionBar(
              actions: [
                SeenButton.destructive(
                  label: busy ? l10n.loading : l10n.walletTopUpCancelAction,
                  loading: busy,
                  expand: true,
                  onPressed: busy ? null : () => _confirmCancel(context),
                ),
              ],
            );
          },
        );
      case _Variant.topUpRejected:
        final info = transaction.topUp;
        return SeenActionBar(
          actions: [
            SeenButton(
              label: l10n.walletResubmitAction,
              expand: true,
              onPressed: () {
                final bloc = context.read<WalletBloc>();
                Navigator.of(context).push(
                  TopUpRequestScreen.route(
                    bloc,
                    prefill: TopUpPrefill(
                      amountCents: transaction.amountCents,
                      method: info?.method ?? TopUpMethod.unknown,
                      referenceNumber: info?.transferReference,
                    ),
                  ),
                );
              },
            ),
            SeenButton.outline(
              label: l10n.requestNotCancellableSupport,
              expand: true,
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SupportTicketsScreen())),
            ),
          ],
        );
    }
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showSeenSheet<bool>(
      context: context,
      title: l10n.walletTopUpCancelConfirmTitle,
      subtitle: l10n.walletTopUpCancelConfirmMessage,
      builder: (_) => const SizedBox.shrink(),
      footerBuilder: (sheetContext) => Row(
        children: [
          Expanded(
            child: SeenButton.secondary(
              label: l10n.requestCancelBack,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ),
          const SizedBox(width: SeenSpace.s3),
          Expanded(
            child: SeenButton.destructive(
              label: l10n.requestCancelConfirm,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<TopUpCancelCubit>().cancel(transaction.id);
    }
  }
}

// ----------------------------------------------------------------- bodies

class _LedgerBody extends StatelessWidget {
  const _LedgerBody({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final credit = transaction.side == LedgerSide.credit;
    final isHold = transaction.type == TransactionType.hold;
    final tone = isHold
        ? SeenRequestStatus.actionRequired
        : credit
            ? SeenRequestStatus.completed
            : SeenRequestStatus.rejected;
    final typeLabel = isHold ? l10n.walletTxnTypeHoldRow : WalletLabels.transactionType(l10n, transaction.type);
    final request = transaction.request;
    final ref = transaction.referenceId;
    final when = '${s.dayMonth(transaction.createdAt)} · ${SeenFormat.time(transaction.createdAt)}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s1, _gutter, SeenSpace.s6),
      children: [
        _AmountHeader(
          chipStatus: tone,
          chipLabel: WalletLabels.transactionType(l10n, transaction.type),
          amount: '${SeenFormat.signed(transaction.amountCents / 100, credit: credit)} USD',
          amountColor: tone.colors.fg,
          caption: isHold ? l10n.walletTxnHoldCaption : null,
        ),
        const SizedBox(height: 14),
        _DetailsCard(
          rows: [
            _Row(l10n.walletTxnRowType, typeLabel),
            if (request != null)
              _Row(
                l10n.walletTxnRowRequest,
                request.serviceName == null
                    ? SeenFormat.isolate(request.referenceId)
                    : '${SeenFormat.isolate(request.referenceId)} · ${request.serviceName}',
              ),
            _Row(l10n.walletTxnRowDate, '${s.dayMonth(transaction.createdAt)} ${transaction.createdAt.year} · ${SeenFormat.time(transaction.createdAt)}'),
            if (transaction.balanceAfterCents != null)
              _Row(l10n.walletTxnRowBalanceAfter, SeenFormat.usd(transaction.balanceAfterCents! / 100)),
          ],
          reference: ref == null || ref.isEmpty ? null : ref,
        ),
        if (_steps(l10n, when) case final steps?) ...[
          const SizedBox(height: 14),
          _TimelineCard(steps: steps),
        ],
      ],
    );
  }

  /// The money's path. Only holds, deductions, refunds and releases have one.
  List<_Step>? _steps(AppLocalizations l10n, String when) => switch (transaction.type) {
        TransactionType.hold => [
            _Step(l10n.walletTlHeld, _StepState.done, caption: when),
            _Step(l10n.walletTlHoldDeduct, _StepState.current),
            _Step(l10n.walletTlHoldRefund, _StepState.future, caption: l10n.walletTlAutomatic),
          ],
        TransactionType.finalDeduction => [
            _Step(l10n.walletTlHeld, _StepState.done),
            _Step(l10n.walletTlDeducted, _StepState.done, caption: when),
          ],
        TransactionType.refund => [
            _Step(l10n.walletTlHeld, _StepState.done),
            _Step(l10n.walletTlRefunded, _StepState.done, caption: when),
          ],
        TransactionType.release => [
            _Step(l10n.walletTlHeld, _StepState.done),
            _Step(l10n.walletTlReleased, _StepState.done, caption: when),
          ],
        _ => null,
      };
}

class _TopUpPendingBody extends StatelessWidget {
  const _TopUpPendingBody({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final info = transaction.topUp;
    final method = info == null ? null : WalletLabels.topUpMethod(l10n, info.method);
    final methodValue = method == null
        ? null
        : (info?.bankName == null ? method : '$method · ${info!.bankName}');
    final captionForMethod = switch (info?.method) {
      TopUpMethod.bankTransfer => l10n.topUpMethodBankTransferCaption,
      TopUpMethod.cash => l10n.topUpMethodCashCaption,
      TopUpMethod.exchangeHouse => l10n.topUpMethodExchangeHouseCaption,
      _ => null,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s1, _gutter, SeenSpace.s6),
      children: [
        _AmountHeader(
          chipStatus: SeenRequestStatus.underReview,
          chipLabel: l10n.requestDocStatusInReview,
          amount: '${SeenFormat.money(transaction.amountCents / 100)} USD',
          amountColor: c.ink,
        ),
        const SizedBox(height: 14),
        if (info?.receiptName != null) ...[
          _ReceiptCard(name: info!.receiptName!, url: info.receiptUrl, reference: info.code),
          const SizedBox(height: 14),
        ],
        _TimelineCard(
          steps: [
            _Step(l10n.walletTlSent, _StepState.done,
                caption: '${s.dayMonth(transaction.createdAt)} · ${SeenFormat.time(transaction.createdAt)}'),
            _Step(l10n.walletTlFinanceReview, _StepState.current, caption: captionForMethod),
            _Step(l10n.walletTlAddedToBalance, _StepState.future, caption: l10n.walletTlAfterApproval),
          ],
        ),
        const SizedBox(height: 14),
        _DetailsCard(
          rows: [
            if (methodValue != null) _Row(l10n.walletTopUpRowMethod, methodValue),
            if (info?.transferReference != null)
              _Row(l10n.walletTopUpRowTransferNo, SeenFormat.isolate(info!.transferReference!)),
          ],
        ),
      ],
    );
  }
}

class _TopUpRejectedBody extends StatelessWidget {
  const _TopUpRejectedBody({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final tone = SeenRequestStatus.rejected.colors;
    final reason = transaction.topUp?.rejectionReason;
    return ListView(
      padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s1, _gutter, SeenSpace.s6),
      children: [
        _AmountHeader(
          chipStatus: SeenRequestStatus.rejected,
          chipLabel: WalletLabels.transactionStatus(l10n, TransactionStatus.rejected),
          amount: '${SeenFormat.money(transaction.amountCents / 100)} USD',
          amountColor: c.inkMuted,
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(color: tone.bg, borderRadius: const BorderRadius.all(SeenRadius.r20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.walletRejectedReasonTitle, style: t.title.copyWith(color: tone.fg)),
                const SizedBox(height: 8),
                Text(
                  reason == null || reason.isEmpty ? l10n.walletRejectedNoReason : reason,
                  style: t.body.copyWith(color: tone.fg),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(l10n.walletRejectedReuseNote, style: t.caption.copyWith(color: c.inkMuted)),
      ],
    );
  }
}

// ------------------------------------------------------------ shared parts

class _AmountHeader extends StatelessWidget {
  const _AmountHeader({
    required this.chipStatus,
    required this.chipLabel,
    required this.amount,
    required this.amountColor,
    this.caption,
  });

  final SeenRequestStatus chipStatus;
  final String chipLabel;
  final String amount;
  final Color amountColor;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Column(
        children: [
          SeenStatusChip(status: chipStatus, label: chipLabel),
          const SizedBox(height: 6),
          Text(
            amount,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: t.amountXl.copyWith(color: amountColor),
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!, style: t.caption.copyWith(color: c.inkMuted)),
          ],
        ],
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.value);

  final String label;
  final String value;
}

/// Label at the start, value at the end, and — for a ledger entry — the
/// transaction reference with a copy action.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.rows, this.reference});

  final List<_Row> rows;
  final String? reference;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows) ...[
            Row(
              children: [
                Text(row.label, style: t.body.copyWith(color: c.inkSecondary)),
                const SizedBox(width: 12),
                Expanded(child: Text(row.value, textAlign: TextAlign.end, style: t.bodyStrong.copyWith(color: c.ink))),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (reference != null)
            DecoratedBox(
              decoration: const BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(SeenRadius.r14)),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.walletTxnReference(SeenFormat.isolate(reference!)),
                        style: t.label.copyWith(color: c.ink),
                      ),
                    ),
                    SeenTextLink(label: l10n.walletTxnCopy, onTap: () => _copy(context, reference!)),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String value) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.walletTxnCopied)));
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.name, this.url, this.reference});

  final String name;
  final String? url;
  final String? reference;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final link = url;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(10))),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(child: SeenSvgIcon(SeenVectors.previewDoc, size: 20)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.label.copyWith(color: c.ink),
              ),
            ),
            if (link != null && link.isNotEmpty)
              SeenTextLink(
                label: l10n.walletReceiptView,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RequestDocumentViewerScreen.file(url: link, name: name, referenceLabel: reference),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, current, future }

class _Step {
  const _Step(this.title, this.state, {this.caption});

  final String title;
  final _StepState state;
  final String? caption;
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.steps});

  final List<_Step> steps;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return _Card(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      _Marker(state: steps[i].state),
                      if (i < steps.length - 1)
                        Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: c.border)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 14 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: (steps[i].state == _StepState.current ? t.bodyStrong : t.body).copyWith(
                              color: steps[i].state == _StepState.future ? c.inkMuted : c.ink,
                            ),
                          ),
                          if (steps[i].caption != null)
                            Text(steps[i].caption!, style: t.caption.copyWith(color: c.inkMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.state});

  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return switch (state) {
      _StepState.done => DecoratedBox(
          decoration: const BoxDecoration(color: SeenBrand.violet, shape: BoxShape.circle),
          child: SizedBox(width: 20, height: 20, child: Icon(SeenIcons.check, size: 12, color: c.card)),
        ),
      _StepState.current => const DecoratedBox(
          decoration: BoxDecoration(
            color: SeenBrand.violet10,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(BorderSide(color: SeenBrand.violet, width: 2)),
          ),
          child: SizedBox(width: 20, height: 20),
        ),
      _StepState.future => DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            shape: BoxShape.circle,
            border: Border.all(color: c.borderStrong, width: 1.5),
          ),
          child: const SizedBox(width: 20, height: 20),
        ),
    };
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

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
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
