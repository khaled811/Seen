import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
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
    this.attachmentFileId,
  });

  final String localId;
  final String ticketId;
  final String body;
  final DateTime sentAt;
  final OutboxStatus status;

  /// The file staged for this message, sent again with it on a retry.
  final String? attachmentFileId;

  OutboxMessage withStatus(OutboxStatus status) => OutboxMessage(
        localId: localId,
        ticketId: ticketId,
        body: body,
        sentAt: sentAt,
        status: status,
        attachmentFileId: attachmentFileId,
      );

  @override
  List<Object?> get props => [localId, ticketId, body, sentAt, status, attachmentFileId];
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
  const SupportFailure(this.message, {this.failure});

  final String message;

  /// What went wrong, for the user-facing text.
  final Failure? failure;

  @override
  List<Object?> get props => [message, failure];
}

final class SupportLoaded extends SupportState {
  const SupportLoaded({
    required this.tickets,
    this.createStatus = CreateTicketStatus.idle,
    this.createError,
    this.createFailure,
    this.createdTicketId,
    this.replyStatus = ReplyStatus.idle,
    this.replyError,
    this.replyFailure,
    this.replyingTicketId,
    this.outbox = const [],
    this.openingTicketId,
    this.openFailure,
    this.openFailureSeq = 0,
  });

  final List<SupportTicket> tickets;

  final CreateTicketStatus createStatus;
  final String? createError;
  final Failure? createFailure;

  /// One-shot: set for exactly the emission right after ticket creation
  /// succeeds; the UI navigates to that ticket's detail then dispatches
  /// `SupportTicketCreateAcknowledged` to clear it.
  final String? createdTicketId;

  final ReplyStatus replyStatus;
  final String? replyError;
  final Failure? replyFailure;
  final String? replyingTicketId;

  /// The ticket whose thread is being read from the server right now.
  final String? openingTicketId;

  /// The last thread that could not be read (the screen shows a retry); the
  /// counter changes per failure so the screen reacts once each time.
  final Failure? openFailure;
  final int openFailureSeq;

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
    Failure? createFailure,
    bool clearCreateError = false,
    String? createdTicketId,
    bool clearCreatedTicketId = false,
    ReplyStatus? replyStatus,
    String? replyError,
    Failure? replyFailure,
    bool clearReplyError = false,
    String? replyingTicketId,
    bool clearReplyingTicketId = false,
    List<OutboxMessage>? outbox,
    String? openingTicketId,
    bool clearOpeningTicketId = false,
    Failure? openFailure,
    bool clearOpenFailure = false,
  }) =>
      SupportLoaded(
        tickets: tickets ?? this.tickets,
        createStatus: createStatus ?? this.createStatus,
        createError: clearCreateError ? null : (createError ?? this.createError),
        createFailure: clearCreateError ? null : (createFailure ?? this.createFailure),
        createdTicketId:
            clearCreatedTicketId ? null : (createdTicketId ?? this.createdTicketId),
        replyStatus: replyStatus ?? this.replyStatus,
        replyError: clearReplyError ? null : (replyError ?? this.replyError),
        replyFailure: clearReplyError ? null : (replyFailure ?? this.replyFailure),
        replyingTicketId:
            clearReplyingTicketId ? null : (replyingTicketId ?? this.replyingTicketId),
        outbox: outbox ?? this.outbox,
        openingTicketId: clearOpeningTicketId ? null : (openingTicketId ?? this.openingTicketId),
        openFailure: clearOpenFailure ? null : (openFailure ?? this.openFailure),
        openFailureSeq: openFailure != null ? openFailureSeq + 1 : openFailureSeq,
      );

  @override
  List<Object?> get props => [
        tickets,
        createStatus,
        createError,
        createFailure,
        createdTicketId,
        replyStatus,
        replyError,
        replyFailure,
        replyingTicketId,
        outbox,
        openingTicketId,
        openFailure,
        openFailureSeq,
      ];
}
