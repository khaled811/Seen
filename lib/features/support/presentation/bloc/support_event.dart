import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

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
    this.attachmentFileId,
    this.categoryCode,
  });

  final TicketCategory category;
  final String subject;
  final String message;
  final String? requestId;
  final TicketPriority priority;

  /// A file already staged on the server (`POST /files/upload/`, `ticket_attachment`).
  final String? attachmentFileId;

  /// The server's code of the category the person picked (`ticketCategories`); when null the
  /// [category] decides.
  final String? categoryCode;

  @override
  List<Object?> get props => [category, subject, message, requestId, priority, attachmentFileId, categoryCode];
}

/// Dispatched by the UI once it has acted on a freshly-created ticket
/// (navigated to its detail), so returning to the list doesn't re-trigger
/// navigation.
final class SupportTicketCreateAcknowledged extends SupportEvent {
  const SupportTicketCreateAcknowledged();
}

final class SupportTicketReplySubmitted extends SupportEvent {
  const SupportTicketReplySubmitted({required this.ticketId, required this.message, this.attachmentFileId});

  final String ticketId;
  final String message;
  final String? attachmentFileId;

  @override
  List<Object?> get props => [ticketId, message, attachmentFileId];
}

/// Sends a message that failed to send again (Figma SUP-03 "resend").
final class SupportOutboxRetryRequested extends SupportEvent {
  const SupportOutboxRetryRequested(this.localId);

  final String localId;

  @override
  List<Object?> get props => [localId];
}

/// The thread was opened: its messages are read from the server.
final class SupportTicketOpened extends SupportEvent {
  const SupportTicketOpened(this.ticketId);

  final String ticketId;

  @override
  List<Object?> get props => [ticketId];
}

/// The agent opened the thread: its unread-reply marker goes away.
final class SupportTicketMarkedRead extends SupportEvent {
  const SupportTicketMarkedRead(this.ticketId);

  final String ticketId;

  @override
  List<Object?> get props => [ticketId];
}
