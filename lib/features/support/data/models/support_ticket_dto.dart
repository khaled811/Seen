import '../../../../core/constants/enums.dart';
import '../../../../core/localization/app_language.dart';
import '../../domain/entities/support_ticket.dart';
import 'ticket_message_dto.dart';

/// Parses a contract `Ticket`.
///
/// The contract's `Ticket` has no subject field: it carries a `payload` (JSON)
/// that holds what the agent typed. Its keys are not published (DECISIONS Q22),
/// so the subject is read from `payload.subject` when there, and otherwise the
/// ticket is named by its category.
abstract final class SupportTicketDto {
  /// The fields the list and the thread both select.
  static const fields = r'''
    id
    type
    category
    priority
    status
    createdAt
    payload
    isUnread
    unreadCount
    categoryInfo { code nameAr nameEn }
    relatedRequest { id referenceCode }
  ''';

  static SupportTicket parse(Map<String, dynamic> json, AppLanguage language, {required bool withMessages}) {
    final payload = json['payload'];
    final subject = payload is Map && payload['subject'] is String && (payload['subject'] as String).trim().isNotEmpty
        ? (payload['subject'] as String).trim()
        : _categoryName(json['categoryInfo'], language);
    final related = json['relatedRequest'];
    final id = json['id'].toString();
    return SupportTicket(
      id: id,
      referenceId: id,
      category: TicketCategory.fromValue(json['category'] as String?),
      priority: TicketPriority.fromValue(json['priority'] as String?),
      subject: subject,
      requestId: related is Map ? related['id']?.toString() : null,
      status: SupportTicketStatus.fromValue(json['status'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
      hasUnreadReply: json['isUnread'] == true,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      messages: [
        for (final m in json['messages'] as List<dynamic>? ?? const [])
          if (m is Map<String, dynamic>) TicketMessageDto.parse(m),
      ],
      messagesLoaded: withMessages,
    );
  }

  static String _categoryName(Object? info, AppLanguage language) {
    if (info is! Map) return '';
    return language.pick(ar: info['nameAr'] as String?, en: info['nameEn'] as String?);
  }
}
