// Domain (NotificationEventType) -> presentation (SeenNotificationKind)
// reconciliation. The two vocabularies don't line up 1:1 (8 domain values
// vs. 7 design-system tones), so this is a deliberate, explicit mapping
// rather than an assumed equivalence.
import '../../../../core/constants/enums.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/feedback.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../domain/entities/in_app_notification.dart';

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

/// How each of the 8 event types looks in the feed (Figma NOTIF-02): its icon and the
/// status tone behind it.
extension NotificationEventTypeVisual on NotificationEventType {
  ({IconData icon, SeenRequestStatus tone}) get visual => switch (this) {
        NotificationEventType.newRequest => (icon: SeenIcons.list, tone: SeenRequestStatus.newRequest),
        NotificationEventType.statusUpdate => (icon: SeenIcons.search, tone: SeenRequestStatus.processing),
        NotificationEventType.infoRequired => (icon: SeenIcons.alert, tone: SeenRequestStatus.actionRequired),
        NotificationEventType.rejected => (icon: SeenIcons.x, tone: SeenRequestStatus.rejected),
        NotificationEventType.slaBreach => (icon: SeenIcons.clock, tone: SeenRequestStatus.deadlineUnder24h),
        NotificationEventType.topUp => (icon: SeenIcons.wallet, tone: SeenRequestStatus.completed),
        NotificationEventType.newAgentSignup => (icon: SeenIcons.users, tone: SeenRequestStatus.submitted),
        NotificationEventType.ticketUpdate => (icon: SeenIcons.chat, tone: SeenRequestStatus.underReview),
        NotificationEventType.unknown => (icon: SeenIcons.info, tone: SeenRequestStatus.newRequest),
      };

  /// The small "→ ..." hint naming where a tap leads.
  String hint(SeenStrings s) => switch (this) {
        NotificationEventType.newRequest => s.isArabic ? 'فتح الطلب' : 'Open the request',
        NotificationEventType.statusUpdate => s.isArabic ? 'التتبع' : 'Tracking',
        NotificationEventType.infoRequired => s.isArabic ? 'رفع المستند' : 'Upload the document',
        NotificationEventType.rejected => s.isArabic ? 'التفاصيل' : 'Details',
        NotificationEventType.slaBreach => s.isArabic ? 'الدعم' : 'Support',
        NotificationEventType.topUp => s.isArabic ? 'المحفظة' : 'Wallet',
        NotificationEventType.newAgentSignup => s.isArabic ? 'ملف الوكيل' : 'Agent profile',
        NotificationEventType.ticketUpdate => s.isArabic ? 'المحادثة' : 'Conversation',
        NotificationEventType.unknown => '',
      };
}

/// Where tapping a notification leads.
enum NotificationTarget { request, ticket, support, wallet, agents }

/// The destination of [n], or null when it has nothing to open. What the
/// notification points at (a request, a ticket) decides first, because the
/// event vocabulary of the server is not published; the type only decides for
/// the ones that point at nothing in particular.
NotificationTarget? notificationTarget(InAppNotification n) {
  if (n.relatedRequestId != null) return NotificationTarget.request;
  if (n.relatedEntityId != null) return NotificationTarget.ticket;
  return switch (n.type) {
    NotificationEventType.topUp => NotificationTarget.wallet,
    NotificationEventType.newAgentSignup => NotificationTarget.agents,
    NotificationEventType.slaBreach || NotificationEventType.ticketUpdate => NotificationTarget.support,
    _ => n.amountCents != null ? NotificationTarget.wallet : null,
  };
}
