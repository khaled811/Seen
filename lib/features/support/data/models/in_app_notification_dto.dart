import '../../../../core/constants/enums.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/in_app_notification.dart';

/// Parses `PortalNotificationList` / `PortalNotification` (contract reference).
abstract final class InAppNotificationDto {
  static NotificationsPage parsePage(Map<String, dynamic> json, AppLanguage language) => NotificationsPage(
        items: [
          for (final item in json['items'] as List<dynamic>? ?? const [])
            if (item is Map<String, dynamic>) parse(item, language),
        ],
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        hasMore: json['hasMore'] == true,
      );

  static InAppNotification parse(Map<String, dynamic> json, AppLanguage language) {
    // `eventType` is the precise one; `kind` is the coarser fallback. Anything the
    // app does not know is "unknown" (neutral).
    final byEvent = _typeOf(json['eventType'] as String?);
    final type = byEvent != NotificationEventType.unknown ? byEvent : _typeOf(json['kind'] as String?);
    final amount = json['amount'];
    return InAppNotification(
      id: json['id'].toString(),
      type: type,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] == true,
      relatedRequestId: json['requestId']?.toString(),
      relatedEntityId: json['ticketId']?.toString(),
      referenceCode: _nonEmpty(json['referenceCode']),
      serviceName: _nonEmpty(language.pick(ar: json['serviceNameAr'] as String?, en: json['serviceNameEn'] as String?)),
      travelerLabel: _nonEmpty(json['travelerLabel']),
      amountCents: amount == null ? null : MoneyParser.centsFromDecimalString(amount.toString()),
      currency: _nonEmpty(json['currency']),
      ticketSubject: _nonEmpty(json['ticketSubject']),
    );
  }

  /// The server's notification kinds (backend answer 2026-10-21) onto the app's event types.
  static const _serverKinds = <String, NotificationEventType>{
    'request_submitted': NotificationEventType.newRequest,
    'request_under_review': NotificationEventType.statusUpdate,
    'request_processing': NotificationEventType.statusUpdate,
    'request_completed': NotificationEventType.statusUpdate,
    'request_cancelled': NotificationEventType.statusUpdate,
    'output_ready': NotificationEventType.statusUpdate,
    'companion_due': NotificationEventType.statusUpdate,
    'assigned': NotificationEventType.statusUpdate,
    'request_rejected': NotificationEventType.rejected,
    'info_required': NotificationEventType.infoRequired,
    'sla_breach': NotificationEventType.slaBreach,
    'topup_requested': NotificationEventType.topUp,
    'topup_approved': NotificationEventType.topUp,
    'topup_rejected': NotificationEventType.topUp,
    'low_balance': NotificationEventType.topUp,
    'ticket_update': NotificationEventType.ticketUpdate,
  };

  static NotificationEventType _typeOf(String? value) =>
      _serverKinds[value] ?? NotificationEventType.fromValue(value);

  static String? _nonEmpty(Object? value) => value is String && value.trim().isNotEmpty ? value : null;
}
