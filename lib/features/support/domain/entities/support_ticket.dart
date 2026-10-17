import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import 'ticket_message.dart';

/// A ticket's lifecycle stage.
///
/// TODO(backend-contract): our confirmed Task 01 enum catalog's
/// `TicketStatus` has only two values (`open`, `closed`), but this
/// feature's business rules call for four (Open/In Progress/Resolved/
/// Closed). Rather than force a lossy 4-into-2 mapping or silently pretend
/// the extra states exist server-side, this is a separate, explicitly
/// placeholder enum — confirm with the backend whether it truly tracks
/// four stages before wiring this to a real API.
enum SupportTicketStatus {
  open('open'),
  inProgress('in_progress'),
  resolved('resolved'),
  closed('closed'),
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

  /// When the thread last moved: the newest message, else the creation time.
  DateTime get lastActivityAt => messages.isEmpty ? createdAt : messages.last.sentAt;

  /// The newest message is support's and the ticket is still live: the next
  /// move is the agent's ("waiting for your action", Figma SUP-01).
  bool get awaitingAgent =>
      isLive && messages.isNotEmpty && messages.last.isSupportReply;

  /// Not resolved or closed.
  bool get isLive => status != SupportTicketStatus.closed && status != SupportTicketStatus.resolved;

  /// A closed ticket is read-only until it is reopened (Figma SUP-03).
  bool get isClosed => status == SupportTicketStatus.closed;

  SupportTicket copyWith({bool? hasUnreadReply, List<TicketMessage>? messages}) => SupportTicket(
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
      ];
}
