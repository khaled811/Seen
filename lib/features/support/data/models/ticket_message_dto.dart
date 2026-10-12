import '../../domain/entities/ticket_message.dart';

class TicketMessageDto {
  const TicketMessageDto({
    required this.id,
    required this.authorName,
    required this.isSupportReply,
    required this.body,
    required this.sentAt,
  });

  factory TicketMessageDto.fromJson(Map<String, dynamic> json) => TicketMessageDto(
        id: json['id'] as String,
        authorName: json['authorName'] as String,
        isSupportReply: json['isSupportReply'] as bool,
        body: json['body'] as String,
        sentAt: DateTime.parse(json['sentAt'] as String),
      );

  final String id;
  final String authorName;
  final bool isSupportReply;
  final String body;
  final DateTime sentAt;

  TicketMessage toEntity() => TicketMessage(
        id: id,
        authorName: authorName,
        isSupportReply: isSupportReply,
        body: body,
        sentAt: sentAt,
      );
}
