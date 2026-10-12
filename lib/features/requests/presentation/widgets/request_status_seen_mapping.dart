// Domain (RequestStatus / TravelerApprovalStatus) -> presentation
// (SeenStatus) reconciliation. `seen_status.dart`'s own doc comment flags
// this as a deliberate follow-up, not done during the widget migration —
// this is that follow-up, shared by the home feed, the requests dashboard
// and the request detail screen rather than duplicated per call site.
import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_status.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../domain/entities/request_traveler_status.dart';

extension RequestStatusSeenMapping on RequestStatus {
  SeenStatus get toSeenStatus => switch (this) {
        RequestStatus.draft ||
        RequestStatus.submitted ||
        RequestStatus.pendingAgentApproval ||
        RequestStatus.pendingManagementApproval ||
        RequestStatus.processing ||
        RequestStatus.unknown =>
          SeenStatus.pending,
        RequestStatus.underReview => SeenStatus.review,
        RequestStatus.infoRequired => SeenStatus.action,
        RequestStatus.completed => SeenStatus.completed,
        RequestStatus.rejected || RequestStatus.cancelled => SeenStatus.rejected,
      };
}

extension TravelerApprovalStatusSeenMapping on TravelerApprovalStatus {
  SeenStatus get toSeenStatus => switch (this) {
        TravelerApprovalStatus.approved => SeenStatus.approved,
        TravelerApprovalStatus.rejected => SeenStatus.rejected,
        TravelerApprovalStatus.pending || TravelerApprovalStatus.unknown => SeenStatus.pending,
      };
}

/// Where a request is on the 5-step journey shown on request cards:
/// 1 received · 2 documents review · 3 with the authority · 4 approval ·
/// 5 issued. Derived from the backend status only (the API has no step field).
class SeenRequestProgress {
  const SeenRequestProgress({required this.step, this.waiting = false, this.total = 5});

  /// Steps completed or in progress; 0 = no meaningful progress (rejected,
  /// cancelled, unknown) — the card hides the progress row.
  final int step;

  /// The current step is blocked on the agency (action required): drawn amber.
  final bool waiting;
  final int total;

  bool get isVisible => step > 0;
}

extension RequestStatusSeenRequestMapping on RequestStatus {
  /// Presentation status for the 12 Figma chips.
  ///  * `infoRequired` is client-evaluated against the 72h SLA: expired once
  ///    the deadline passed, "under 24h" inside the last day, otherwise plain
  ///    action required.
  ///  * `withAuthority` and `confirmed` have no backend value, so they are not
  ///    produced here (the "with the authority" wording is the progress step
  ///    of a `processing` request).
  SeenRequestStatus toSeenRequestStatus({DateTime? slaDeadline, DateTime? now}) => switch (this) {
        RequestStatus.draft || RequestStatus.unknown => SeenRequestStatus.newRequest,
        RequestStatus.submitted ||
        RequestStatus.pendingAgentApproval ||
        RequestStatus.pendingManagementApproval =>
          SeenRequestStatus.submitted,
        RequestStatus.underReview => SeenRequestStatus.underReview,
        RequestStatus.infoRequired => _infoRequired(slaDeadline, now ?? DateTime.now()),
        RequestStatus.processing => SeenRequestStatus.processing,
        RequestStatus.completed => SeenRequestStatus.completed,
        RequestStatus.rejected => SeenRequestStatus.rejected,
        RequestStatus.cancelled => SeenRequestStatus.cancelled,
      };

  SeenRequestProgress get progress => switch (this) {
        RequestStatus.draft ||
        RequestStatus.submitted ||
        RequestStatus.pendingAgentApproval ||
        RequestStatus.pendingManagementApproval =>
          const SeenRequestProgress(step: 1),
        RequestStatus.underReview => const SeenRequestProgress(step: 2),
        RequestStatus.infoRequired => const SeenRequestProgress(step: 2, waiting: true),
        RequestStatus.processing => const SeenRequestProgress(step: 3),
        RequestStatus.completed => const SeenRequestProgress(step: 5),
        RequestStatus.rejected || RequestStatus.cancelled || RequestStatus.unknown => const SeenRequestProgress(step: 0),
      };
}

SeenRequestStatus _infoRequired(DateTime? deadline, DateTime now) {
  if (deadline == null) return SeenRequestStatus.actionRequired;
  final left = deadline.difference(now);
  if (left <= Duration.zero) return SeenRequestStatus.expired;
  if (left < const Duration(hours: 24)) return SeenRequestStatus.deadlineUnder24h;
  return SeenRequestStatus.actionRequired;
}

/// Countdown pill state for an SLA [deadline] (null when there is nothing to count).
SeenCountdownState? seenCountdownState(DateTime? deadline, {DateTime? now}) {
  if (deadline == null) return null;
  final left = deadline.difference(now ?? DateTime.now());
  if (left <= Duration.zero) return SeenCountdownState.expired;
  return left < const Duration(hours: 24) ? SeenCountdownState.urgent : SeenCountdownState.warm;
}
