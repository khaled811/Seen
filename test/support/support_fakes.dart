import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/support/domain/entities/in_app_notification.dart';
import 'package:seen_booking/features/support/domain/entities/support_ticket.dart';
import 'package:seen_booking/features/support/domain/entities/ticket_message.dart';
import 'package:seen_booking/features/support/domain/repositories/support_repository.dart';

InAppNotification fakeNotification(
  String id, {
  NotificationEventType type = NotificationEventType.statusUpdate,
  bool read = false,
  String? request,
  String? ticket,
  String? subject,
  String? reference,
  int? amountCents,
  DateTime? createdAt,
}) =>
    InAppNotification(
      id: id,
      type: type,
      createdAt: createdAt ?? DateTime.now(),
      isRead: read,
      relatedRequestId: request,
      relatedEntityId: ticket,
      referenceCode: reference,
      ticketSubject: subject,
      amountCents: amountCents,
      currency: amountCents == null ? null : 'USD',
    );

/// A server for the notification calls of [SupportRepository]: it really pages,
/// filters by `unreadOnly` and counts unread, like the contract says. Everything
/// else is not used by the notification tests.
class FakeNotificationsRepository implements SupportRepository {
  FakeNotificationsRepository(this.items);

  List<InAppNotification> items;
  Failure? failure;
  Failure? markFailure;
  bool markResult = true;
  final pages = <({bool unreadOnly, int limit, int offset})>[];
  final marked = <String>[];
  int markAllCalls = 0;
  int unreadCountCalls = 0;
  Either<Failure, int>? unreadCountResult;
  Completer<void>? markAllGate;

  int get unread => items.where((n) => !n.isRead).length;

  @override
  Future<Either<Failure, NotificationsPage>> getNotifications({bool unreadOnly = false, int limit = 20, int offset = 0}) async {
    pages.add((unreadOnly: unreadOnly, limit: limit, offset: offset));
    final f = failure;
    if (f != null) return Left(f);
    final matching = [for (final n in items) if (!unreadOnly || !n.isRead) n];
    final page = matching.skip(offset).take(limit).toList();
    return Right(NotificationsPage(
      items: page,
      unreadCount: unread,
      total: matching.length,
      hasMore: offset + page.length < matching.length,
    ));
  }

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async {
    unreadCountCalls++;
    return unreadCountResult ?? Right(unread);
  }

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async {
    marked.add(notificationId);
    final f = markFailure;
    if (f != null) return Left(f);
    if (markResult) {
      items = [for (final n in items) if (n.id == notificationId) n.copyWith(isRead: true) else n];
    }
    return Right(markResult);
  }

  @override
  Future<Either<Failure, int>> markAllNotificationsRead() async {
    markAllCalls++;
    await markAllGate?.future;
    final f = markFailure;
    if (f != null) return Left(f);
    final count = unread;
    items = [for (final n in items) n.copyWith(isRead: true)];
    return Right(count);
  }

  @override
  Future<Either<Failure, List<SupportTicket>>> getTickets() => throw UnimplementedError('Not used by notifications');

  @override
  Future<Either<Failure, SupportTicket>> getTicket(String ticketId) => throw UnimplementedError('Not used by notifications');

  @override
  Future<Either<Failure, SupportTicket>> createTicket({
    required TicketCategory category,
    required String subject,
    required String message,
    String? requestId,
    TicketPriority priority = TicketPriority.normal,
    String? attachmentFileId,
      String? categoryCode,
  }) =>
      throw UnimplementedError('Not used by notifications');

  @override
  Future<Either<Failure, TicketMessage>> replyToTicket({required String ticketId, required String message, String? attachmentFileId}) =>
      throw UnimplementedError('Not used by notifications');
}
