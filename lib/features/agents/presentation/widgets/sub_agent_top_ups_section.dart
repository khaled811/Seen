import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/sub_agent_top_up.dart';
import '../bloc/sub_agent_top_ups_cubit.dart';

/// The funding requests of the sub-agencies (`pendingSubAgentTopUps`) in the approvals
/// screen: each with Approve (after a confirmation that says how much leaves the main
/// agent's wallet) and Reject. Needs the [SubAgentTopUpsCubit] above it.
class SubAgentTopUpsSection extends StatelessWidget {
  const SubAgentTopUpsSection({super.key, this.onApproved});

  /// Called after a request was approved (balances changed: the list reads them again).
  final VoidCallback? onApproved;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<SubAgentTopUpsCubit, SubAgentTopUpsState>(
      listenWhen: (p, n) => p.decision.seq != n.decision.seq,
      listener: (context, state) {
        final d = state.decision;
        final message = switch (d.kind) {
          TopUpDecisionKind.approved => s.topUpApproved,
          TopUpDecisionKind.rejected => s.topUpRejected,
          TopUpDecisionKind.failed => failureTextOr(l10n, d.failure, l10n.error),
          TopUpDecisionKind.none => null,
        };
        if (message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
        if (d.kind == TopUpDecisionKind.approved) onApproved?.call();
      },
      builder: (context, state) {
        // Nothing to say while loading, when there is nothing waiting, or when this account
        // may not see them (the requests below stay the screen's own business).
        if (state.items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(s.topUpRequestsTitle(s.numeral(state.items.length)), style: t.title),
            ),
            for (final item in state.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: const BorderRadius.all(SeenRadius.r22),
                    border: Border.all(color: c.border),
                    boxShadow: SeenShadows.card,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(item.agentName, style: t.label)),
                            Text(SeenFormat.usd(item.amountCents / 100), style: t.bodyStrong),
                          ],
                        ),
                        if (item.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(item.note, style: t.caption.copyWith(color: c.inkMuted)),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SeenButton(
                                label: state.busyId == item.id ? l10n.loading : l10n.agentApprovalApprove,
                                loading: state.busyId == item.id,
                                size: SeenButtonSize.small,
                                expand: true,
                                onPressed: state.busyId != null ? null : () => _approve(context, item),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SeenButton.outline(
                                label: l10n.agentApprovalReject,
                                size: SeenButtonSize.small,
                                expand: true,
                                onPressed: state.busyId != null ? null : () => context.read<SubAgentTopUpsCubit>().reject(item.id),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _approve(BuildContext context, SubAgentTopUp item) async {
    final s = SeenStrings.of(context);
    final cubit = context.read<SubAgentTopUpsCubit>();
    // Money leaves the main agent's own wallet: ask once, with the figures.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.topUpApproveTitle(item.agentName)),
        content: Text(s.topUpApproveBody(SeenFormat.usd(item.amountCents / 100))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(AppLocalizations.of(context)!.errorCancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.topUpApproveConfirm)),
        ],
      ),
    );
    if (ok == true) await cubit.approve(item.id);
  }
}
