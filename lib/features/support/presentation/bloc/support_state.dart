import 'package:equatable/equatable.dart';

import '../../domain/entities/support_ticket.dart';

enum CreateTicketStatus { idle, submitting, success, failure }

enum ReplyStatus { idle, submitting, success, failure }

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
      ];
}
