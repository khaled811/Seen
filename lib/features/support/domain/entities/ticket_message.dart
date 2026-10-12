import 'package:equatable/equatable.dart';

/// One message in a ticket's chat-style thread.
class TicketMessage extends Equatable {
  const TicketMessage({
    required this.id,
    required this.authorName,
    required this.isSupportReply,
    required this.body,
    required this.sentAt,
  });

  final String id;
  final String authorName;

  /// `true` when this message is from the support team; `false` when it's
  /// from the agent who opened the ticket — drives which side of the chat
  /// it renders on.
  final bool isSupportReply;

  final String body;
  final DateTime sentAt;

  @override
  List<Object?> get props => [id, authorName, isSupportReply, body, sentAt];
}
