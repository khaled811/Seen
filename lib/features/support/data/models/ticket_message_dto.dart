import '../../domain/entities/ticket_message.dart';

/// Parses a contract `TicketMessage`. Who sent it: a user with no agency is
/// Seen's support (contract: an account without an agency is Seen staff); a user
/// of the agency is the agent side.
abstract final class TicketMessageDto {
  static const fields = 'id message createdAt attachmentFileId attachmentName sender { id fullName agent { id } }';

  static TicketMessage parse(Map<String, dynamic> json) {
    final sender = json['sender'];
    return TicketMessage(
      id: json['id'].toString(),
      authorName: sender is Map ? (sender['fullName'] as String? ?? '') : '',
      isSupportReply: sender is Map && sender['agent'] == null,
      body: json['message'] as String? ?? '',
      sentAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
