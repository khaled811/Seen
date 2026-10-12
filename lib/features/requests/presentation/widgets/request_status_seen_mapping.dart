// Domain (RequestStatus / TravelerApprovalStatus) -> presentation
// (SeenStatus) reconciliation. `seen_status.dart`'s own doc comment flags
// this as a deliberate follow-up, not done during the widget migration —
// this is that follow-up, shared by the home feed, the requests dashboard
// and the request detail screen rather than duplicated per call site.
import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_status.dart';
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
