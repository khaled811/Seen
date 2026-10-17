import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import '../../domain/entities/support_ticket.dart';

sealed class SupportEvent extends Equatable {
  const SupportEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on the tickets screen's entry, and on pull-to-refresh.
final class SupportTicketsLoadRequested extends SupportEvent {
  const SupportTicketsLoadRequested();
}

final class SupportTicketCreateSubmitted extends SupportEvent {
  const SupportTicketCreateSubmitted({
    required this.category,
    required this.subject,
    required this.message,
    this.requestId,
    this.priority = TicketPriority.normal,
  });

  final TicketCategory category;
  final String subject;
  final String message;
  final String? requestId;
  final TicketPriority priority;

  @override
  List<Object?> get props => [category, subject, message, requestId, priority];
}

/// Dispatched by the UI once it has acted on a freshly-created ticket
/// (navigated to its detail), so returning to the list doesn't re-trigger
/// navigation.
final class SupportTicketCreateAcknowledged extends SupportEvent {
  const SupportTicketCreateAcknowledged();
}

final class SupportTicketReplySubmitted extends SupportEvent {
  const SupportTicketReplySubmitted({required this.ticketId, required this.message});

  final String ticketId;
  final String message;

  @override
  List<Object?> get props => [ticketId, message];
}

/// Sends a message that failed to send again (Figma SUP-03 "resend").
final class SupportOutboxRetryRequested extends SupportEvent {
  const SupportOutboxRetryRequested(this.localId);

  final String localId;

  @override
  List<Object?> get props => [localId];
}

/// A ticket changed outside the bloc (reopened): the list adopts the new version.
final class SupportTicketReplaced extends SupportEvent {
  const SupportTicketReplaced(this.ticket);

  final SupportTicket ticket;

  @override
  List<Object?> get props => [ticket];
}

/// The agent opened the thread: its unread-reply marker goes away.
final class SupportTicketMarkedRead extends SupportEvent {
  const SupportTicketMarkedRead(this.ticketId);

  final String ticketId;

  @override
  List<Object?> get props => [ticketId];
}
