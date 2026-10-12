import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/support_ticket.dart' show SupportTicketStatus;
import '../models/in_app_notification_dto.dart';
import '../models/support_ticket_dto.dart';
import '../models/ticket_message_dto.dart';
import 'support_remote_data_source.dart';

/// DEBUG ONLY — decorates a real [SupportRemoteDataSource] and, only when a
/// real call fails in a debug build, substitutes canned tickets and
/// notifications. Same pattern (and the same reasoning) as every other
/// feature's debug fallback this session: `kDebugMode` is a compile-time
/// constant, so every fallback branch below is dead-code-eliminated in
/// release.
class DebugFallbackSupportRemoteDataSource implements SupportRemoteDataSource {
  DebugFallbackSupportRemoteDataSource(this._real);

  final SupportRemoteDataSource _real;

  /// In-memory only — reset on app restart, never touches real persistence.
  final Map<String, SupportTicketDto> _mockTickets = _seedTickets();
  final Map<String, InAppNotificationDto> _mockNotifications = _seedNotifications();
  int _nextTicketId = 100;

  @override
  Future<Either<Failure, List<SupportTicketDto>>> getTickets() async {
    final result = await _real.getTickets();
    if (kDebugMode && result.isLeft()) return Right(_mockTickets.values.toList());
    return result;
  }

  @override
  Future<Either<Failure, SupportTicketDto>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
  }) async {
    final result = await _real.createTicket(
      category: category,
      subject: subject,
      message: message,
      requestId: requestId,
    );
    if (kDebugMode && result.isLeft()) {
      final id = 'ticket-${_nextTicketId++}';
      final ticket = SupportTicketDto(
        id: id,
        referenceId: 'TCK-$_nextTicketId',
        category: category.value,
        priority: 'normal',
        subject: subject,
        requestId: requestId,
        status: SupportTicketStatus.open.value,
        createdAt: DateTime.now(),
        messages: [
          TicketMessageDto(
            id: '$id-msg-1',
            authorName: 'You',
            isSupportReply: false,
            body: message,
            sentAt: DateTime.now(),
          ),
        ],
      );
      _mockTickets[id] = ticket;
      return Right(ticket);
    }
    return result;
  }

  @override
  Future<Either<Failure, SupportTicketDto>> replyToTicket({
    required String ticketId,
    required String message,
  }) async {
    final result = await _real.replyToTicket(ticketId: ticketId, message: message);
    if (kDebugMode && result.isLeft()) {
      final existing = _mockTickets[ticketId];
      if (existing == null) {
        return const Left(ServerFailure('Ticket not found.'));
      }
      final updated = SupportTicketDto(
        id: existing.id,
        referenceId: existing.referenceId,
        category: existing.category,
        priority: existing.priority,
        subject: existing.subject,
        requestId: existing.requestId,
        status: existing.status,
        createdAt: existing.createdAt,
        messages: [
          ...existing.messages,
          TicketMessageDto(
            id: '${existing.id}-msg-${existing.messages.length + 1}',
            authorName: 'You',
            isSupportReply: false,
            body: message,
            sentAt: DateTime.now(),
          ),
        ],
      );
      _mockTickets[ticketId] = updated;
      return Right(updated);
    }
    return result;
  }

  @override
  Future<Either<Failure, List<InAppNotificationDto>>> getNotifications() async {
    final result = await _real.getNotifications();
    if (kDebugMode && result.isLeft()) {
      return Right(_mockNotifications.values.toList());
    }
    return result;
  }

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async {
    final result = await _real.markNotificationRead(notificationId);
    if (kDebugMode && result.isLeft()) {
      final existing = _mockNotifications[notificationId];
      if (existing == null) return const Left(ServerFailure('Notification not found.'));
      _mockNotifications[notificationId] = InAppNotificationDto(
        id: existing.id,
        type: existing.type,
        title: existing.title,
        body: existing.body,
        createdAt: existing.createdAt,
        isRead: true,
        relatedRequestId: existing.relatedRequestId,
      );
      return const Right(true);
    }
    return result;
  }

  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async {
    final result = await _real.markAllNotificationsRead();
    if (kDebugMode && result.isLeft()) {
      for (final id in _mockNotifications.keys.toList()) {
        final existing = _mockNotifications[id]!;
        _mockNotifications[id] = InAppNotificationDto(
          id: existing.id,
          type: existing.type,
          title: existing.title,
          body: existing.body,
          createdAt: existing.createdAt,
          isRead: true,
          relatedRequestId: existing.relatedRequestId,
        );
      }
      return const Right(true);
    }
    return result;
  }
}

Map<String, SupportTicketDto> _seedTickets() {
  final now = DateTime.now();
  final tickets = [
    SupportTicketDto(
      id: 'ticket-1',
      referenceId: 'TCK-1001',
      category: 'general',
      priority: 'normal',
      subject: 'Question about Egypt visa processing time',
      status: 'open',
      createdAt: now.subtract(const Duration(days: 1)),
      messages: [
        TicketMessageDto(
          id: 'ticket-1-msg-1',
          authorName: 'You',
          isSupportReply: false,
          body: 'How long does National Security approval usually take?',
          sentAt: now.subtract(const Duration(days: 1)),
        ),
      ],
    ),
    SupportTicketDto(
      id: 'ticket-2',
      referenceId: 'TCK-1002',
      category: 'general',
      priority: 'high',
      subject: 'Request stuck in review',
      requestId: 'req-3',
      status: 'in_progress',
      createdAt: now.subtract(const Duration(days: 3)),
      messages: [
        TicketMessageDto(
          id: 'ticket-2-msg-1',
          authorName: 'You',
          isSupportReply: false,
          body: 'This request has been under review for 3 days, can you check?',
          sentAt: now.subtract(const Duration(days: 3)),
        ),
        TicketMessageDto(
          id: 'ticket-2-msg-2',
          authorName: 'Support (Layla)',
          isSupportReply: true,
          body: "We've escalated this to the National Security desk — thanks for your patience.",
          sentAt: now.subtract(const Duration(days: 2)),
        ),
      ],
    ),
    SupportTicketDto(
      id: 'ticket-3',
      referenceId: 'TCK-1003',
      category: 'financial_correction',
      priority: 'urgent',
      subject: 'Wallet top-up not reflected',
      status: 'resolved',
      createdAt: now.subtract(const Duration(days: 6)),
      messages: [
        TicketMessageDto(
          id: 'ticket-3-msg-1',
          authorName: 'You',
          isSupportReply: false,
          body: "I sent a bank transfer top-up but it's not showing in my wallet.",
          sentAt: now.subtract(const Duration(days: 6)),
        ),
        TicketMessageDto(
          id: 'ticket-3-msg-2',
          authorName: 'Support (Omar)',
          isSupportReply: true,
          body: 'Confirmed and applied — your balance has been updated.',
          sentAt: now.subtract(const Duration(days: 5)),
        ),
      ],
    ),
    SupportTicketDto(
      id: 'ticket-4',
      referenceId: 'TCK-1004',
      category: 'general',
      priority: 'low',
      subject: 'How to add a new sub-agent branch?',
      status: 'closed',
      createdAt: now.subtract(const Duration(days: 12)),
      messages: [
        TicketMessageDto(
          id: 'ticket-4-msg-1',
          authorName: 'You',
          isSupportReply: false,
          body: 'Is there a way to add a new branch under my account?',
          sentAt: now.subtract(const Duration(days: 12)),
        ),
        TicketMessageDto(
          id: 'ticket-4-msg-2',
          authorName: 'Support (Layla)',
          isSupportReply: true,
          body: 'Please contact your account manager to request a new branch.',
          sentAt: now.subtract(const Duration(days: 11)),
        ),
      ],
    ),
  ];
  return {for (final t in tickets) t.id: t};
}

Map<String, InAppNotificationDto> _seedNotifications() {
  final now = DateTime.now();
  final notifications = [
    InAppNotificationDto(
      id: 'notif-1',
      type: 'info_required',
      title: 'Action required',
      body: 'SB-1005 needs additional documents — SLA overdue.',
      createdAt: now.subtract(const Duration(hours: 1)),
      isRead: false,
      relatedRequestId: 'req-5',
    ),
    InAppNotificationDto(
      id: 'notif-2',
      type: 'sla_breach',
      title: 'SLA breach warning',
      body: 'SB-1004 is within 6 hours of its response deadline.',
      createdAt: now.subtract(const Duration(hours: 3)),
      isRead: false,
      relatedRequestId: 'req-4',
    ),
    InAppNotificationDto(
      id: 'notif-3',
      type: 'status_update',
      title: 'Request under review',
      body: 'SB-1003 moved to Under Review.',
      createdAt: now.subtract(const Duration(hours: 20)),
      isRead: false,
      relatedRequestId: 'req-3',
    ),
    InAppNotificationDto(
      id: 'notif-4',
      type: 'top_up',
      title: 'Wallet top-up approved',
      body: 'Your \$2,000.00 top-up (TXN-1001) has been approved.',
      createdAt: now.subtract(const Duration(days: 1)),
      isRead: true,
    ),
    InAppNotificationDto(
      id: 'notif-5',
      type: 'rejected',
      title: 'Request rejected',
      body: 'SB-1007 was rejected — passport expiry did not meet requirements.',
      createdAt: now.subtract(const Duration(days: 5)),
      isRead: true,
      relatedRequestId: 'req-7',
    ),
    InAppNotificationDto(
      id: 'notif-6',
      type: 'new_request',
      title: 'New sub-agent request',
      body: 'Cairo Branch submitted a new request awaiting your approval.',
      createdAt: now.subtract(const Duration(hours: 5)),
      isRead: false,
    ),
    InAppNotificationDto(
      id: 'notif-7',
      type: 'ticket_update',
      title: 'Ticket reply',
      body: 'Support replied to TCK-1002.',
      createdAt: now.subtract(const Duration(days: 2)),
      isRead: true,
    ),
  ];
  return {for (final n in notifications) n.id: n};
}
