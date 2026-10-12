// Domain (NotificationEventType) -> presentation (SeenNotificationKind)
// reconciliation. The two vocabularies don't line up 1:1 (8 domain values
// vs. 7 design-system tones), so this is a deliberate, explicit mapping
// rather than an assumed equivalence.
import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/widgets/feedback.dart';

extension NotificationEventTypeSeenMapping on NotificationEventType {
  SeenNotificationKind get toSeenKind => switch (this) {
        NotificationEventType.newRequest => SeenNotificationKind.review,
        NotificationEventType.statusUpdate => SeenNotificationKind.system,
        NotificationEventType.infoRequired => SeenNotificationKind.action,
        NotificationEventType.rejected => SeenNotificationKind.action,
        NotificationEventType.slaBreach => SeenNotificationKind.sla,
        NotificationEventType.topUp => SeenNotificationKind.wallet,
        NotificationEventType.newAgentSignup => SeenNotificationKind.agent,
        NotificationEventType.ticketUpdate => SeenNotificationKind.system,
        NotificationEventType.unknown => SeenNotificationKind.system,
      };
}
