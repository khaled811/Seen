// Status-specific blocks of the request detail (Figma REQ-06 … 09): waiting on
// an approval, rejected, cancelled / expired. Each is the body of the detail
// screen for that status; the sticky actions live in `request_status_actions`.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/request_detail.dart';

/// The statuses these sections cover.
bool hasStatusSection(RequestDetail d, {DateTime? now}) =>
    d.status == RequestStatus.pendingAgentApproval ||
    d.status == RequestStatus.pendingManagementApproval ||
    d.status == RequestStatus.rejected ||
    d.status == RequestStatus.cancelled ||
    isExpiredByDeadline(d, now: now);

/// Cancelled automatically for the missed upload deadline, or still marked
/// "info required" with the deadline already past.
bool isExpiredByDeadline(RequestDetail d, {DateTime? now}) {
  if (d.cancellation?.expiredByDeadline == true) return true;
  final deadline = d.slaDeadline;
  return d.status == RequestStatus.infoRequired && deadline != null && !deadline.isAfter(now ?? DateTime.now());
}

Widget _card(SeenColors c, Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );

/// A tinted banner: icon and one text.
class _Banner extends StatelessWidget {
  const _Banner({required this.colors, required this.icon, required this.message});

  final SeenStatusColors colors;
  final String icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bg, borderRadius: const BorderRadius.all(SeenRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SeenSvgIcon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: t.label.copyWith(color: colors.fg))),
          ],
        ),
      ),
    );
  }
}

/// "6 hours" / "2 days" style wait, rounded to something a person says.
String _wait(int minutes, SeenStrings s) {
  if (minutes < 60) return s.durationMinutes(minutes);
  final hours = (minutes / 60).round();
  return s.durationHours(hours);
}

// ----------------------------------------------------------- REQ-06 / REQ-07

/// Waiting on the master agent (06) or on management (07): the request card with
/// its progress, who approves and why.
class RequestApprovalSection extends StatelessWidget {
  const RequestApprovalSection({super.key, required this.detail});

  final RequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final management = detail.status == RequestStatus.pendingManagementApproval;
    final approval = detail.approval;
    final kind = approval?.kind ?? (management ? ApproverKind.management : ApproverKind.masterAgent);
    final chipStatus = management ? SeenRequestStatus.actionRequired : SeenRequestStatus.underReview;
    final chipLabel = management ? l10n.requestWaitingManagement : l10n.requestWaitingAgent;
    final approverName = approval?.approverName ?? (kind == ApproverKind.management ? l10n.requestApproverManagement : null);
    final approverLine = approverName == null
        ? null
        : kind == ApproverKind.masterAgent
            ? l10n.requestApproverIs('$approverName ${l10n.requestApproverMasterAgent}')
            : l10n.requestApproverIs(approverName);
    final initial = approverName == null || approverName.trim().isEmpty ? '' : String.fromCharCodes(approverName.trim().runes.take(1));
    final banner = management
        ? (approval?.thresholdCents == null
            ? l10n.requestApprovalBannerManagementNoAmount
            : l10n.requestApprovalBannerManagement(SeenFormat.usd(approval!.thresholdCents! / 100)))
        : l10n.requestApprovalBannerAgent;
    return Column(
      children: [
        _card(
          c,
          Column(
            children: [
              Row(
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(SeenRadius.r12)),
                    child: SizedBox(width: 40, height: 40, child: Center(child: SeenSvgIcon(SeenVectors.iconRequests, size: 22))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${detail.serviceName} · ${s.travelerCount(detail.travelers.length)}',
                      style: t.label,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Long status words shrink instead of overflowing on narrow screens.
                  Flexible(
                    child: FittedBox(fit: BoxFit.scaleDown, child: SeenStatusChip(status: chipStatus, label: chipLabel)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < 5; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: i < 1 ? SeenBrand.progressDone : SeenBrand.progressTodo,
                          borderRadius: const BorderRadius.all(Radius.circular(3)),
                        ),
                        child: const SizedBox(height: 5),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '$chipLabel · ${s.stepOf(1, 5)}',
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          c,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.requestWhoApproves, style: t.title),
              const SizedBox(height: 10),
              Row(
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(color: SeenBrand.violet10, shape: BoxShape.circle),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(child: Text(initial, style: t.label.copyWith(color: SeenBrand.violet))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (approverLine != null) Text(approverLine, style: t.label),
                        if (approval?.typicalWaitMinutes != null)
                          Text(
                            l10n.requestApproverEta(_wait(approval!.typicalWaitMinutes!, s)),
                            style: t.caption.copyWith(color: c.inkMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Banner(colors: SeenRequestStatus.underReview.colors, icon: SeenVectors.infoReview, message: banner),
      ],
    );
  }
}

// ------------------------------------------------------------------- REQ-08

/// Rejected: the red ticket, the authority's reason, the refund, support.
class RequestRejectedSection extends StatelessWidget {
  const RequestRejectedSection({super.key, required this.detail, required this.onSupport});

  final RequestDetail detail;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final bad = SeenRequestStatus.rejected.colors;
    final lead = detail.travelers.isNotEmpty ? detail.travelers.first.name : null;
    final title = lead == null ? detail.serviceName : '$lead · ${detail.serviceName}';
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: bad.bg, borderRadius: const BorderRadius.all(SeenRadius.r24)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        SeenFormat.isolate(detail.referenceId),
                        style: t.label.copyWith(color: bad.fg),
                      ),
                    ),
                    SeenStatusChip(status: SeenRequestStatus.rejected, label: s.requestStatus(SeenRequestStatus.rejected)),
                  ],
                ),
                const SizedBox(height: 8),
                Align(alignment: AlignmentDirectional.centerStart, child: Text(title, style: t.h2)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _card(
          c,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.requestRejectionReasonTitle, style: t.title),
              const SizedBox(height: 8),
              Text(
                (detail.rejectionReason ?? '').isEmpty ? l10n.requestRejectionNoReason : detail.rejectionReason!,
                style: t.body.copyWith(color: c.inkSecondary),
              ),
            ],
          ),
        ),
        if (detail.refundedCents != null) ...[
          const SizedBox(height: 14),
          _Banner(
            colors: SeenRequestStatus.completed.colors,
            icon: SeenVectors.walletCheck,
            message: l10n.requestRefundedAvailable(SeenFormat.usd(detail.refundedCents! / 100)),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: SeenButton.secondary(
            label: l10n.recoveryContactSupport,
            size: SeenButtonSize.small,
            expand: true,
            onPressed: onSupport,
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- REQ-09

/// Cancelled by a person, or expired for the missed upload deadline.
class RequestCancelledSection extends StatelessWidget {
  const RequestCancelledSection({super.key, required this.detail, this.now});

  final RequestDetail detail;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final expired = isExpiredByDeadline(detail, now: now);
    final info = detail.cancellation;
    final lead = detail.travelers.isNotEmpty ? detail.travelers.first.name : null;
    final when = info?.cancelledAt;
    final whenText = when == null ? null : '${s.dayMonth(when)} ${SeenFormat.time(when)}';
    final who = info?.cancelledBy;
    final refund = detail.refundedCents == null ? null : SeenFormat.usd(detail.refundedCents! / 100);

    if (expired) {
      return _card(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${SeenFormat.isolate(detail.referenceId)} · ${detail.serviceName}', style: t.label),
                ),
                SeenStatusChip(status: SeenRequestStatus.expired, label: s.requestStatus(SeenRequestStatus.expired)),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.requestExpiredNote(s.numeral(72)), style: t.caption.copyWith(color: c.inkSecondary)),
            if (refund != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.requestExpiredRefund(refund),
                style: t.caption.copyWith(color: SeenRequestStatus.completed.colors.fg),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        _card(
          c,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${SeenFormat.isolate(detail.referenceId)} · ${lead ?? detail.serviceName}',
                      style: t.label,
                    ),
                  ),
                  SeenStatusChip(status: SeenRequestStatus.cancelled, label: s.requestStatus(SeenRequestStatus.cancelled)),
                ],
              ),
              if (who != null || whenText != null) ...[
                const SizedBox(height: 8),
                Text(
                  [if (who != null) l10n.requestCancelledBy(who), if (whenText != null) whenText].join(' · '),
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ],
              if ((info?.reason ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l10n.requestCancelReasonLine(info!.reason!), style: t.caption.copyWith(color: c.inkSecondary)),
              ],
            ],
          ),
        ),
        if (refund != null) ...[
          const SizedBox(height: 14),
          _Banner(
            colors: SeenRequestStatus.completed.colors,
            icon: SeenVectors.walletCheck,
            message: l10n.requestRefundedShort(refund),
          ),
        ],
      ],
    );
  }
}
