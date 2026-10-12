import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_motion_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/avatar.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/motion_icon.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/steppers.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';
import '../../domain/entities/request_detail.dart';
import '../../domain/entities/request_traveler_status.dart';
import '../bloc/requests_bloc.dart';
import '../bloc/requests_event.dart';
import '../bloc/requests_state.dart';
import '../widgets/request_status_labels.dart';
import '../widgets/request_status_seen_mapping.dart';

/// The request's SLA window — every deadline is 72h from submission. Used
/// both for `SeenSlaTag`'s "x of 72" caption and the elapsed-share progress
/// bar under the summary card.
const _slaTotalHours = 72;

enum _DetailMenuAction { copyReference, contactSupport }

class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<RequestsBloc, RequestsState>(
      listenWhen: (previous, current) =>
          current is RequestsLoaded && current.cancelStatus == RequestCancelStatus.failure,
      listener: (context, state) {
        final message = (state as RequestsLoaded).cancelError ?? l10n.error;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(SeenSize.appBar),
          child: BlocBuilder<RequestsBloc, RequestsState>(
            buildWhen: (previous, current) => current is RequestsLoaded && current.detail != null,
            builder: (context, state) {
              final referenceId = state is RequestsLoaded ? state.detail?.referenceId : null;
              return SeenTopBar.inner(
                title: l10n.requestDetailTitle,
                subtitle: referenceId,
                trailing: PopupMenuButton<_DetailMenuAction>(
                  icon: Icon(SeenIcons.more, color: SeenColors.of(context).slate, size: 22),
                  onSelected: (action) async {
                    switch (action) {
                      case _DetailMenuAction.copyReference:
                        if (referenceId == null) return;
                        await Clipboard.setData(ClipboardData(text: referenceId));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(l10n.requestDetailReferenceCopiedMessage)));
                      case _DetailMenuAction.contactSupport:
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const SupportTicketsScreen()));
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _DetailMenuAction.copyReference,
                      child: Text(l10n.requestDetailCopyReferenceAction),
                    ),
                    PopupMenuItem(
                      value: _DetailMenuAction.contactSupport,
                      child: Text(l10n.requestDetailContactSupportAction),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        body: BlocBuilder<RequestsBloc, RequestsState>(
          builder: (context, state) {
            if (state is! RequestsLoaded || state.detail == null) {
              if (state is RequestsLoaded && state.detailStatus == RequestDetailStatus.failure) {
                return _DetailErrorView(message: state.detailError ?? l10n.error);
              }
              return const _DetailSkeleton();
            }
            return _DetailBody(state: state, detail: state.detail!);
          },
        ),
        bottomNavigationBar: BlocBuilder<RequestsBloc, RequestsState>(
          buildWhen: (previous, current) => current is RequestsLoaded && current.detail != null,
          builder: (context, state) {
            if (state is! RequestsLoaded || state.detail == null) return const SizedBox.shrink();
            return _DownloadApprovalsBar(detail: state.detail!);
          },
        ),
      ),
    );
  }
}

class _DownloadApprovalsBar extends StatelessWidget {
  const _DownloadApprovalsBar({required this.detail});

  final RequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final approvedCount =
        detail.travelers.where((t) => t.status == TravelerApprovalStatus.approved).length;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: c.sheetShadow,
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(SeenSpace.s4),
          child: SeenButton.secondary(
            label: approvedCount > 0
                ? l10n.requestDetailDownloadApprovalsAction(approvedCount)
                : l10n.requestDetailDownloadApprovalsUnavailable,
            icon: SeenIcons.download,
            expand: true,
            onPressed: approvedCount > 0 ? () {} : null,
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.state, required this.detail});

  final RequestsLoaded state;
  final RequestDetail detail;

  Future<void> _confirmCancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showSeenSheet<bool>(
      context: context,
      title: l10n.requestDetailCancelConfirmTitle,
      subtitle: l10n.requestDetailCancelConfirmMessage,
      builder: (_) => const SizedBox.shrink(),
      footerBuilder: (sheetContext) => Row(
        children: [
          Expanded(
            child: SeenButton.secondary(
              label: l10n.no,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ),
          const SizedBox(width: SeenSpace.s3),
          Expanded(
            child: SeenButton.dangerOutline(
              label: l10n.yes,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<RequestsBloc>().add(RequestCancelSubmitted(detail.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    final isCancelling = state.cancelStatus == RequestCancelStatus.submitting;

    return ListView(
      padding: const EdgeInsets.all(SeenSpace.s4),
      children: [
        Container(
          padding: const EdgeInsets.all(SeenSpace.s4),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.all(SeenRadius.md),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (detail.slaDeadline != null)
                    SeenSlaTag(deadline: detail.slaDeadline!, totalHours: _slaTotalHours)
                  else
                    const SizedBox.shrink(),
                  SeenStatusBadge(status: detail.status.toSeenStatus),
                ],
              ),
              const SizedBox(height: SeenSpace.s3),
              Text(detail.serviceName, style: text.titleMedium),
              const SizedBox(height: SeenSpace.s1),
              Text(
                '${l10n.requestCardTravelersLabel(detail.travelers.length)} · '
                '${l10n.requestDetailSubmittedPrefix} ${SeenFormat.isolate('${SeenFormat.date(detail.submittedAt)} ${SeenFormat.time(detail.submittedAt)}')} · '
                '${l10n.requestDetailHeldPrefix} ${SeenFormat.usd(detail.totalPriceCents / 100)}',
                style: text.bodySmall!.copyWith(color: c.inkMuted),
              ),
              if (detail.slaDeadline != null) ...[
                const SizedBox(height: SeenSpace.s3),
                _SlaProgressBar(deadline: detail.slaDeadline!),
              ],
            ],
          ),
        ),
        if (detail.travelers.isNotEmpty) ...[
          const SizedBox(height: SeenSpace.s6),
          SeenSectionHeader(title: l10n.requestDetailTravelersSection),
          SeenListGroup(children: [
            for (var i = 0; i < detail.travelers.length; i++)
              _TravelerRow(traveler: detail.travelers[i], number: i + 1),
          ]),
        ],
        if (detail.timeline.isNotEmpty) ...[
          const SizedBox(height: SeenSpace.s6),
          SeenSectionHeader(title: l10n.requestDetailTimelineSection),
          Container(
            padding: const EdgeInsets.all(SeenSpace.s4),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.all(SeenRadius.md),
              border: Border.all(color: c.border),
            ),
            child: Builder(
              builder: (context) {
                String stageTitle(RequestStatus status) => switch (status) {
                      RequestStatus.submitted => 'تم الإرسال وحجز المبلغ',
                      RequestStatus.processing => 'التحقق من المستندات',
                      RequestStatus.underReview => 'قيد المراجعة لدى الجهة',
                      RequestStatus.completed => 'صدور الموافقات والخصم النهائي',
                      _ => RequestStatusLabels.of(l10n, status),
                    };

                final steps = <SeenStep>[
                  for (final entry in detail.timeline)
                    SeenStep(
                      title: stageTitle(entry.status),
                      meta: entry.note ??
                          (entry.status == RequestStatus.underReview && detail.slaDeadline != null
                              ? 'متوقع خلال ${detail.slaDeadline!.difference(DateTime.now()).inHours.clamp(0, 72)} ساعة'
                              : SeenFormat.isolate(
                                  '${SeenFormat.date(entry.occurredAt)} · ${SeenFormat.time(entry.occurredAt)}')),
                    ),
                ];
                final hasCompletedStep = detail.timeline.any((e) => e.status == RequestStatus.completed);
                if (!hasCompletedStep &&
                    detail.status != RequestStatus.cancelled &&
                    detail.status != RequestStatus.rejected) {
                  steps.add(SeenStep(title: stageTitle(RequestStatus.completed)));
                }
                return SeenStatusStepper(
                  current: detail.timeline.length - 1,
                  steps: steps,
                );
              },
            ),
          ),
        ],
        if (detail.isCancellable) ...[
          const SizedBox(height: SeenSpace.s6),
          SeenButton.dangerOutline(
            label: isCancelling ? l10n.loading : l10n.requestDetailCancelAction,
            icon: SeenIcons.x,
            expand: true,
            onPressed: isCancelling ? null : () => _confirmCancel(context),
          ),
        ],
      ],
    );
  }
}

/// Elapsed share of the 72h SLA, filled from the reading start. Solid
/// `slaSolid` once under 24h remaining (matching `SeenSlaTag`'s own
/// urgency tone), `primary` otherwise.
class _SlaProgressBar extends StatelessWidget {
  const _SlaProgressBar({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    const total = Duration(hours: _slaTotalHours);
    final remaining = deadline.difference(DateTime.now());
    final elapsed = total - remaining;
    final fraction = (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final urgent = remaining.inHours < 24;

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Container(color: c.surfaceSunken),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: fraction,
              child: Container(color: urgent ? c.slaSolid : c.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelerRow extends StatelessWidget {
  const _TravelerRow({required this.traveler, required this.number});

  final RequestTravelerStatus traveler;

  /// This traveler's 1-based position in the request — shown in the
  /// avatar, matching the spec (a running passenger number, not initials).
  final int number;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    final approved = traveler.status == TravelerApprovalStatus.approved;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: SeenSpace.s3),
      child: Row(children: [
        SeenAvatar(initial: '$number'),
        const SizedBox(width: SeenSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(traveler.name, textDirection: TextDirection.ltr, style: text.bodyMedium),
              if (traveler.passportNumber != null)
                Text(
                  traveler.passportNumber!,
                  textDirection: TextDirection.ltr,
                  style: SeenType.of(context).refMono.copyWith(fontSize: 12, color: c.inkMuted),
                ),
            ],
          ),
        ),
        const SizedBox(width: SeenSpace.s2),
        SeenStatusBadge(status: traveler.status.toSeenStatus, dense: true),
        // Per-traveler download — still mocked (no real document storage
        // yet, same treatment as elsewhere in this app), so tapping only
        // plays the acknowledgment animation.
        if (approved) ...[
          const SizedBox(width: SeenSpace.s1),
          SeenMotionIcon(
            asset: SeenMotionIcons.download,
            fallbackIcon: SeenIcons.download,
            size: 20,
            color: c.inkMuted,
            semanticLabel: l10n.requestDetailDownloadAction,
            onTap: () {},
          ),
        ],
      ]),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);

    Widget block(double height, double width) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(4)),
        );

    return Padding(
      padding: const EdgeInsets.all(SeenSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(SeenSpace.s4),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.all(SeenRadius.md),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    block(24, 90),
                    block(24, 70),
                  ],
                ),
                const SizedBox(height: SeenSpace.s3),
                block(20, 200),
                const SizedBox(height: SeenSpace.s2),
                block(14, 240),
              ],
            ),
          ),
          const SizedBox(height: SeenSpace.s6),
          block(18, 120),
          const SizedBox(height: SeenSpace.s3),
          Container(
            padding: const EdgeInsets.all(SeenSpace.s4),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.all(SeenRadius.md),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(height: SeenSpace.s4),
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: c.surfaceSunken, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: SeenSpace.s3),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          block(16, 160),
                          const SizedBox(height: 4),
                          block(12, 100),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailErrorView extends StatelessWidget {
  const _DetailErrorView({required this.message});

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
            onPressed: () {
              final state = context.read<RequestsBloc>().state;
              if (state is RequestsLoaded && state.requests.isNotEmpty) {
                context.read<RequestsBloc>().add(RequestDetailRequested(state.requests.first.id));
              }
            },
          ),
        ],
      ),
    );
  }
}
