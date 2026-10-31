import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import 'ticket_message.dart';

/// A ticket's lifecycle stage (contract section 13: `open`, `in_progress`,
/// `waiting`, `resolved`, `closed`, `cancelled`). An unknown value is [unknown].
enum SupportTicketStatus {
  open('open'),
  inProgress('in_progress'),
  waiting('waiting'),
  resolved('resolved'),
  closed('closed'),
  cancelled('cancelled'),
  unknown('');

  const SupportTicketStatus(this.value);
  final String value;

  static SupportTicketStatus fromValue(String? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return SupportTicketStatus.unknown;
  }
}

/// A support ticket. Whether it's "request-related" or "general" isn't a
/// category enum — it's simply whether [requestId] is set, since that's a
/// structural link, not a business classification. [category] (from the
/// confirmed Task 01 `TicketCategory` enum) is the genuine categorization
/// axis (e.g. general vs a financial correction).
class SupportTicket extends Equatable {
  const SupportTicket({
    required this.id,
    required this.referenceId,
    required this.category,
    required this.priority,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.messages,
    this.requestId,
    this.hasUnreadReply = false,
    this.unreadCount = 0,
    this.messagesLoaded = true,
  });

  final String id;
  final String referenceId;
  final TicketCategory category;
  final TicketPriority priority;
  final String subject;

  /// Non-null when this ticket is linked to a specific request.
  final String? requestId;

  final SupportTicketStatus status;
  final DateTime createdAt;
  final List<TicketMessage> messages;

  /// Support replied and the agent has not opened the thread since (Figma SUP-01).
  final bool hasUnreadReply;

  /// How many of the thread's newest messages the agent has not read yet (`Ticket.unreadCount`).
  final int unreadCount;

  /// False for a ticket read from the list (no messages came with it): the
  /// thread loads when it is opened.
  final bool messagesLoaded;

  /// When the thread last moved: the newest message, else the creation time.
  DateTime get lastActivityAt => messages.isEmpty ? createdAt : messages.last.sentAt;

  /// The newest message is support's and the ticket is still live: the next
  /// move is the agent's ("waiting for your action", Figma SUP-01).
  bool get awaitingAgent =>
      isLive && messages.isNotEmpty && messages.last.isSupportReply;

  /// Not resolved, closed or cancelled.
  bool get isLive =>
      status != SupportTicketStatus.closed &&
      status != SupportTicketStatus.resolved &&
      status != SupportTicketStatus.cancelled;

  /// Closed and cancelled tickets are final: the thread is read-only. (A `resolved` or
  /// `waiting` ticket is reopened by replying to it: the server does that itself.)
  bool get isFinal => status == SupportTicketStatus.closed || status == SupportTicketStatus.cancelled;

  SupportTicket copyWith({bool? hasUnreadReply, int? unreadCount, List<TicketMessage>? messages, bool? messagesLoaded}) => SupportTicket(
        id: id,
        referenceId: referenceId,
        category: category,
        priority: priority,
        subject: subject,
        status: status,
        createdAt: createdAt,
        messages: messages ?? this.messages,
        requestId: requestId,
        hasUnreadReply: hasUnreadReply ?? this.hasUnreadReply,
        unreadCount: unreadCount ?? this.unreadCount,
        messagesLoaded: messagesLoaded ?? this.messagesLoaded,
      );

  bool get isRequestRelated => requestId != null;

  @override
  List<Object?> get props => [
        id,
        referenceId,
        category,
        priority,
        subject,
        requestId,
        status,
        createdAt,
        messages,
        hasUnreadReply,
        unreadCount,
        messagesLoaded,
      ];
}
