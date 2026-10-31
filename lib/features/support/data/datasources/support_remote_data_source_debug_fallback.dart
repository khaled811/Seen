import 'package:fpdart/fpdart.dart';

import '../../../../core/config/debug_fallbacks.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/in_app_notification.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/entities/ticket_message.dart';
import 'support_remote_data_source.dart';
import '../../../../core/utils/app_clock.dart';

/// DEBUG ONLY (opt-in with `USE_DEBUG_FALLBACKS`): decorates a real
/// [SupportRemoteDataSource] and, only when a real call fails in a debug build,
/// answers with canned tickets and notifications held in memory. `kDebugMode` is
/// a compile-time constant, so every fallback branch is removed from release builds.
class DebugFallbackSupportRemoteDataSource implements SupportRemoteDataSource {
  DebugFallbackSupportRemoteDataSource(this._real);

  final SupportRemoteDataSource _real;

  final Map<String, SupportTicket> _tickets = {for (final t in _seedTickets()) t.id: t};
  final Map<String, InAppNotification> _notifications = {for (final n in _seedNotifications()) n.id: n};
  int _nextTicketId = 100;

  bool _fallback(Either<Failure, Object?> result) => debugFallbacksEnabled && result.isLeft();

  @override
  Future<Either<Failure, List<SupportTicket>>> getTickets({int limit = 50, int offset = 0}) async {
    final result = await _real.getTickets(limit: limit, offset: offset);
    if (!_fallback(result)) return result;
    return Right([for (final t in _tickets.values) t.copyWith(messages: const [], messagesLoaded: false)]);
  }

  @override
  Future<Either<Failure, SupportTicket>> getTicket(String ticketId) async {
    final result = await _real.getTicket(ticketId);
    if (!_fallback(result)) return result;
    final ticket = _tickets[ticketId];
    return ticket == null ? const Left(ServerFailure('Ticket not found.')) : Right(ticket);
  }

  @override
  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
    String? attachmentFileId,
    String? categoryCode,
  }) async {
    final result = await _real.createTicket(
      category: category,
      subject: subject,
      message: message,
      requestId: requestId,
      priority: priority,
      attachmentFileId: attachmentFileId,
      categoryCode: categoryCode,
    );
    if (!_fallback(result)) return result;
    final id = 'ticket-${_nextTicketId++}';
    final ticket = SupportTicket(
      id: id,
      referenceId: 'TCK-$_nextTicketId',
      category: category,
      priority: priority,
      subject: subject,
      requestId: requestId,
      status: SupportTicketStatus.open,
      createdAt: DateTime.now(),
      messages: [TicketMessage(id: '$id-msg-1', authorName: 'You', isSupportReply: false, body: message, sentAt: DateTime.now())],
    );
    _tickets[id] = ticket;
    return Right(ticket);
  }

  @override
  Future<Either<Failure, bool>> markTicketRead(String ticketId) async {
    final result = await _real.markTicketRead(ticketId);
    if (!_fallback(result)) return result;
    final ticket = _tickets[ticketId];
    if (ticket != null) _tickets[ticketId] = ticket.copyWith(hasUnreadReply: false);
    return const Right(true);
  }

  @override
  Future<Either<Failure, TicketMessage>> replyToTicket({required String ticketId, required String message, String? attachmentFileId}) async {
    final result = await _real.replyToTicket(ticketId: ticketId, message: message, attachmentFileId: attachmentFileId);
    if (!_fallback(result)) return result;
    final ticket = _tickets[ticketId];
    if (ticket == null) return const Left(ServerFailure('Ticket not found.'));
    final reply = TicketMessage(
      id: '$ticketId-msg-${ticket.messages.length + 1}',
      authorName: 'You',
      isSupportReply: false,
      body: message,
      sentAt: DateTime.now(),
    );
    _tickets[ticketId] = ticket.copyWith(messages: [...ticket.messages, reply]);
    return Right(reply);
  }

  @override
  Future<Either<Failure, NotificationsPage>> getNotifications({bool unreadOnly = false, int limit = 20, int offset = 0}) async {
    final result = await _real.getNotifications(unreadOnly: unreadOnly, limit: limit, offset: offset);
    if (!_fallback(result)) return result;
    final all = [for (final n in _notifications.values) if (!unreadOnly || !n.isRead) n];
    final page = all.skip(offset).take(limit).toList();
    return Right(NotificationsPage(
      items: page,
      unreadCount: _notifications.values.where((n) => !n.isRead).length,
      total: all.length,
      hasMore: offset + page.length < all.length,
    ));
  }

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async {
    final result = await _real.getUnreadNotificationCount();
    if (!_fallback(result)) return result;
    return Right(_notifications.values.where((n) => !n.isRead).length);
  }

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async {
    final result = await _real.markNotificationRead(notificationId);
    if (!_fallback(result)) return result;
    final existing = _notifications[notificationId];
    if (existing == null) return const Right(false);
    _notifications[notificationId] = existing.copyWith(isRead: true);
    return const Right(true);
  }

  @override
  Future<Either<Failure, int>> markAllNotificationsRead() async {
    final result = await _real.markAllNotificationsRead();
    if (!_fallback(result)) return result;
    var marked = 0;
    for (final id in _notifications.keys.toList()) {
      if (!_notifications[id]!.isRead) marked++;
      _notifications[id] = _notifications[id]!.copyWith(isRead: true);
    }
    return Right(marked);
  }
}

List<SupportTicket> _seedTickets() {
  final now = AppClock.now();
  return [
    SupportTicket(
      id: 'ticket-1',
      referenceId: 'TCK-1001',
      category: TicketCategory.general,
      priority: TicketPriority.normal,
      subject: 'Question about Egypt visa processing time',
      status: SupportTicketStatus.open,
      createdAt: now.subtract(const Duration(days: 1)),
      messages: [
        TicketMessage(
          id: 'ticket-1-msg-1',
          authorName: 'You',
          isSupportReply: false,
          body: 'How long does National Security approval usually take?',
          sentAt: now.subtract(const Duration(days: 1)),
        ),
      ],
    ),
    SupportTicket(
      id: 'ticket-2',
      referenceId: 'TCK-1002',
      category: TicketCategory.general,
      priority: TicketPriority.high,
      subject: 'Request stuck in review',
      requestId: 'req-3',
      status: SupportTicketStatus.inProgress,
      hasUnreadReply: true,
      createdAt: now.subtract(const Duration(days: 3)),
      messages: [
        TicketMessage(
          id: 'ticket-2-msg-1',
          authorName: 'You',
          isSupportReply: false,
          body: 'This request has been under review for 3 days, can you check?',
          sentAt: now.subtract(const Duration(days: 3)),
        ),
        TicketMessage(
          id: 'ticket-2-msg-2',
          authorName: 'Support',
          isSupportReply: true,
          body: "We've escalated this to the National Security desk. Thanks for your patience.",
          sentAt: now.subtract(const Duration(days: 2)),
        ),
      ],
    ),
  ];
}

List<InAppNotification> _seedNotifications() {
  final now = AppClock.now();
  return [
    InAppNotification(
      id: 'notif-1',
      type: NotificationEventType.statusUpdate,
      createdAt: now.subtract(const Duration(hours: 2)),
      isRead: false,
      relatedRequestId: 'req-1',
      referenceCode: 'SB-20476',
      serviceName: 'Egypt National Security Approval',
    ),
    InAppNotification(
      id: 'notif-2',
      type: NotificationEventType.topUp,
      createdAt: now.subtract(const Duration(days: 1)),
      isRead: true,
      amountCents: 50000,
      currency: 'USD',
    ),
  ];
}
