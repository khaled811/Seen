import 'package:equatable/equatable.dart';

import '../../domain/entities/support_ticket.dart';

enum CreateTicketStatus { idle, submitting, success, failure }

enum ReplyStatus { idle, submitting, success, failure }

enum OutboxStatus { sending, failed }

/// A message the agent typed that the server has not confirmed yet. It shows in
/// the thread right away, marked "sending" or "failed" (Figma SUP-03).
class OutboxMessage extends Equatable {
  const OutboxMessage({
    required this.localId,
    required this.ticketId,
    required this.body,
    required this.sentAt,
    this.status = OutboxStatus.sending,
  });

  final String localId;
  final String ticketId;
  final String body;
  final DateTime sentAt;
  final OutboxStatus status;

  OutboxMessage withStatus(OutboxStatus status) =>
      OutboxMessage(localId: localId, ticketId: ticketId, body: body, sentAt: sentAt, status: status);

  @override
  List<Object?> get props => [localId, ticketId, body, sentAt, status];
}

sealed class SupportState extends Equatable {
  const SupportState();

  @override
  List<Object?> get props => [];
}

final class SupportInitial extends SupportState {
  const SupportInitial();
}

final class SupportLoading extends SupportState {
  const SupportLoading();
}

final class SupportFailure extends SupportState {
  const SupportFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class SupportLoaded extends SupportState {
  const SupportLoaded({
    required this.tickets,
    this.createStatus = CreateTicketStatus.idle,
    this.createError,
    this.createdTicketId,
    this.replyStatus = ReplyStatus.idle,
    this.replyError,
    this.replyingTicketId,
    this.outbox = const [],
  });

  final List<SupportTicket> tickets;

  final CreateTicketStatus createStatus;
  final String? createError;

  /// One-shot: set for exactly the emission right after ticket creation
  /// succeeds; the UI navigates to that ticket's detail then dispatches
  /// `SupportTicketCreateAcknowledged` to clear it.
  final String? createdTicketId;

  final ReplyStatus replyStatus;
  final String? replyError;
  final String? replyingTicketId;

  /// Messages not yet confirmed by the server, oldest first.
  final List<OutboxMessage> outbox;

  List<OutboxMessage> outboxFor(String ticketId) => [for (final m in outbox) if (m.ticketId == ticketId) m];

  SupportTicket? ticketById(String id) {
    for (final ticket in tickets) {
      if (ticket.id == id) return ticket;
    }
    return null;
  }

  SupportLoaded copyWith({
    List<SupportTicket>? tickets,
    CreateTicketStatus? createStatus,
    String? createError,
    bool clearCreateError = false,
    String? createdTicketId,
    bool clearCreatedTicketId = false,
    ReplyStatus? replyStatus,
    String? replyError,
    bool clearReplyError = false,
    String? replyingTicketId,
    bool clearReplyingTicketId = false,
    List<OutboxMessage>? outbox,
  }) =>
      SupportLoaded(
        tickets: tickets ?? this.tickets,
        createStatus: createStatus ?? this.createStatus,
        createError: clearCreateError ? null : (createError ?? this.createError),
        createdTicketId:
            clearCreatedTicketId ? null : (createdTicketId ?? this.createdTicketId),
        replyStatus: replyStatus ?? this.replyStatus,
        replyError: clearReplyError ? null : (replyError ?? this.replyError),
        replyingTicketId:
            clearReplyingTicketId ? null : (replyingTicketId ?? this.replyingTicketId),
        outbox: outbox ?? this.outbox,
      );

  @override
  List<Object?> get props => [
        tickets,
        createStatus,
        createError,
        createdTicketId,
        replyStatus,
        replyError,
        replyingTicketId,
        outbox,
      ];
}
