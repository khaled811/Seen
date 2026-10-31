import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/failure_message.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/sub_agent_request_summary.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/agents_bloc.dart';
import '../bloc/sub_agent_top_ups_cubit.dart';
import '../widgets/sub_agent_top_ups_section.dart';
import '../bloc/agents_event.dart';
import '../bloc/agents_state.dart';

/// Sub-agent approvals (Figma AGT-06): the requests waiting at the master
/// agent's gate, each with Reject (asks for a reason, AGT-07) and Approve. Uses
/// the [AgentsBloc] above it; approved / rejected requests leave the list.
class SubAgentApprovalsScreen extends StatelessWidget {
  const SubAgentApprovalsScreen({super.key, this.createTopUps});

  /// Test seam for the funding-requests cubit; defaults to the DI container.
  final SubAgentTopUpsCubit Function()? createTopUps;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createTopUps ?? InjectionContainer.instance.createSubAgentTopUpsCubit)()..load(),
      child: const _ApprovalsView(),
    );
  }
}

class _ApprovalsView extends StatelessWidget {
  const _ApprovalsView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return BlocConsumer<AgentsBloc, AgentsState>(
      listenWhen: (previous, current) =>
          current is AgentsLoaded &&
          current.approvalActionStatus != ApprovalActionStatus.idle &&
          (previous is! AgentsLoaded ||
              previous.approvalActionStatus != current.approvalActionStatus),
      listener: (context, state) {
        final loaded = state as AgentsLoaded;
        if (loaded.approvalActionStatus == ApprovalActionStatus.submitting) {
          return;
        }
        final message =
            switch ((loaded.approvalActionStatus, loaded.approvalActionKind)) {
          (ApprovalActionStatus.success, ApprovalActionKind.approve) =>
            l10n.agentApprovalApproved,
          (ApprovalActionStatus.success, ApprovalActionKind.reject) =>
            l10n.agentApprovalRejected,
          _ => failureTextOr(l10n, loaded.approvalActionFailure, loaded.approvalActionError ?? l10n.recoveryServerError),
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        context.read<AgentsBloc>().add(const ApprovalStatusCleared());
      },
      builder: (context, state) {
        final pending = state is AgentsLoaded
            ? state.pendingRequests
            : const <SubAgentRequestSummary>[];
        final submittingId = state is AgentsLoaded &&
                state.approvalActionStatus == ApprovalActionStatus.submitting
            ? state.approvalActionRequestId
            : null;
        return Scaffold(
          body: SeenScreenBackground(
            washHeight: 320,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SeenScreenHeader(
                    title: l10n.agentApprovalsTitle,
                    subtitle: pending.isEmpty
                        ? null
                        : l10n.agentApprovalsWaiting(s.numeral(pending.length)),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                      children: [
                        // A sub-agency's own funding requests, when there are any.
                        SubAgentTopUpsSection(onApproved: () => context.read<AgentsBloc>().add(const AgentsLoadRequested())),
                        if (pending.isEmpty)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius:
                                  const BorderRadius.all(SeenRadius.r22),
                              border: Border.all(color: c.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  l10n.agentApprovalsEmpty,
                                  textAlign: TextAlign.center,
                                  style: t.caption.copyWith(color: c.inkMuted),
                                ),
                              ),
                            ),
                          )
                        else
                          for (final r in pending)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ApprovalCard(
                                  request: r,
                                  busy: submittingId == r.id,
                                  anyBusy: submittingId != null),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard(
      {required this.request, required this.busy, required this.anyBusy});

  final SubAgentRequestSummary request;
  final bool busy;
  final bool anyBusy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final initial = request.subAgentName.trim().isEmpty
        ? ''
        : String.fromCharCodes(request.subAgentName.trim().runes.take(1));
    final bloc = context.read<AgentsBloc>();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                      color: SeenBrand.violet10, shape: BoxShape.circle),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                        child: Text(initial,
                            style: t.label.copyWith(color: SeenBrand.violet))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.subAgentName, style: t.label),
                      Text(
                        '${request.serviceName} · ${s.travelerCount(request.travelerCount)}',
                        style: t.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SeenStatusChip(
                    status: SeenRequestStatus.underReview,
                    label: l10n.agentApprovalWaitingChip),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: Text(l10n.agentApprovalValue,
                        style: t.body.copyWith(color: c.inkSecondary))),
                Text(SeenFormat.usd(request.totalPriceCents / 100),
                    style: t.bodyStrong),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SeenButton(
                    label: busy ? l10n.loading : l10n.agentApprovalApprove,
                    loading: busy,
                    size: SeenButtonSize.small,
                    expand: true,
                    onPressed: anyBusy
                        ? null
                        : () => bloc
                            .add(SubAgentRequestApproveSubmitted(request.id)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SeenButton.outline(
                    label: l10n.agentApprovalReject,
                    size: SeenButtonSize.small,
                    expand: true,
                    onPressed: anyBusy
                        ? null
                        : () async {
                            final reason = await showRejectReasonSheet(context,
                                request: request);
                            if (reason != null) {
                              bloc.add(SubAgentRequestRejectSubmitted(
                                  requestId: request.id, reason: reason));
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Reject reason (Figma AGT-07): pick a reason, add a note for the agent. Resolves
/// to the reason text (the picked reason, plus the note when there is one) or
/// `null` when dismissed.
Future<String?> showRejectReasonSheet(BuildContext context,
    {required SubAgentRequestSummary request}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RejectSheet(request: request),
  );
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet({required this.request});

  final SubAgentRequestSummary request;

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  // Owned here, disposed in dispose().
  final _note = TextEditingController();
  int? _picked;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final reasons = [
      l10n.agentRejectReasonLimit,
      l10n.agentRejectReasonIncomplete,
      l10n.agentRejectReasonOther
    ];
    final other = _picked == reasons.length - 1;
    final note = _note.text.trim();
    final valid = _picked != null && (!other || note.isNotEmpty);
    final rejected = SeenRequestStatus.rejected.colors;
    return SeenSheet(
      title: l10n.agentRejectTitle,
      subtitle:
          '${widget.request.subAgentName} · ${widget.request.serviceName}',
      footer: Opacity(
        opacity: valid ? 1 : 0.45,
        child: Semantics(
          button: true,
          enabled: valid,
          label: l10n.agentRejectConfirm,
          excludeSemantics: true,
          child: Material(
            color: rejected.bg,
            borderRadius: const BorderRadius.all(SeenRadius.lg),
            child: InkWell(
              onTap: valid
                  ? () => Navigator.of(context).pop(
                        note.isEmpty
                            ? reasons[_picked!]
                            : '${reasons[_picked!]} — $note',
                      )
                  : null,
              borderRadius: const BorderRadius.all(SeenRadius.lg),
              child: SizedBox(
                height: 52,
                child: Center(
                    child: Text(l10n.agentRejectConfirm,
                        style: t.bodyStrong.copyWith(color: rejected.fg))),
              ),
            ),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, label) in reasons.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                button: true,
                selected: _picked == i,
                label: label,
                excludeSemantics: true,
                child: Material(
                  color: _picked == i ? SeenBrand.violet05 : c.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(SeenRadius.r14),
                    side: BorderSide(
                        color: _picked == i ? SeenBrand.violet : c.border),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _picked = i),
                    customBorder: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(SeenRadius.r14)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(label, style: t.label)),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.card,
                              border: Border.all(
                                  color: _picked == i
                                      ? SeenBrand.violet
                                      : c.borderStrong,
                                  width: _picked == i ? 6 : 1.5),
                            ),
                            child: const SizedBox(width: 22, height: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SeenTextField(
              label: l10n.agentRejectNote, controller: _note, maxLines: 3),
        ],
      ),
    );
  }
}
