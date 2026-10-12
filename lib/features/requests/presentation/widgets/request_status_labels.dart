import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';

/// Exact, ARB-localized label per [RequestStatus] — finer-grained than the
/// design system's 8-word `SeenStatus` vocabulary (e.g. distinguishes
/// "Pending Agent Approval" from "Pending Management Approval", which both
/// collapse to `SeenStatus.pending`). Used where that precision matters,
/// such as each entry in a request's status timeline.
abstract final class RequestStatusLabels {
  static String of(AppLocalizations l10n, RequestStatus status) => switch (status) {
        RequestStatus.draft => l10n.requestStatusDraft,
        RequestStatus.submitted => l10n.requestStatusSubmitted,
        RequestStatus.pendingAgentApproval => l10n.requestStatusPendingAgentApproval,
        RequestStatus.pendingManagementApproval =>
          l10n.requestStatusPendingManagementApproval,
        RequestStatus.underReview => l10n.requestStatusUnderReview,
        RequestStatus.infoRequired => l10n.requestStatusInfoRequired,
        RequestStatus.processing => l10n.requestStatusProcessing,
        RequestStatus.completed => l10n.requestStatusCompleted,
        RequestStatus.rejected => l10n.requestStatusRejected,
        RequestStatus.cancelled => l10n.requestStatusCancelled,
        RequestStatus.unknown => l10n.error,
      };
}
