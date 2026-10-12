import '../../../../core/constants/enums.dart';
import '../../domain/entities/support_ticket.dart';
import 'ticket_message_dto.dart';

/// Wire shape of one support ticket.
///
/// TODO(backend-contract): field names are placeholders pending the real
/// Seen Booking GraphQL schema — update here and in
/// `support_remote_data_source.dart` once confirmed. `status` in particular
/// assumes a 4-value lifecycle the confirmed Task 01 `TicketStatus` enum
/// doesn't have — see the TODO on `SupportTicketStatus`.
class SupportTicketDto {
  const SupportTicketDto({
    required this.id,
    required this.referenceId,
    required this.subject,
    required this.createdAt,
    required this.messages,
    this.category,
    this.priority,
    this.requestId,
    this.status,
  });

  factory SupportTicketDto.fromJson(Map<String, dynamic> json) => SupportTicketDto(
        id: json['id'] as String,
        referenceId: json['referenceId'] as String,
        category: json['category'] as String?,
        priority: json['priority'] as String?,
        subject: json['subject'] as String,
        requestId: json['requestId'] as String?,
        status: json['status'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        messages: (json['messages'] as List<dynamic>)
            .map((e) => TicketMessageDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String referenceId;
  final String? category;
  final String? priority;
  final String subject;
  final String? requestId;
  final String? status;
  final DateTime createdAt;
  final List<TicketMessageDto> messages;

  SupportTicket toEntity() => SupportTicket(
        id: id,
        referenceId: referenceId,
        category: TicketCategory.fromValue(category),
        priority: TicketPriority.fromValue(priority),
        subject: subject,
        requestId: requestId,
        status: SupportTicketStatus.fromValue(status),
        createdAt: createdAt,
        messages: messages.map((dto) => dto.toEntity()).toList(),
      );
}
