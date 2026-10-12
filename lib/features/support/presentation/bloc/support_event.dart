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
  });

  final TicketCategory category;
  final String subject;
  final String message;
  final String? requestId;

  @override
  List<Object?> get props => [category, subject, message, requestId];
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
