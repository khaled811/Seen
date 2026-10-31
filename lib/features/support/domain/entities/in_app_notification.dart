import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// One entry in the in-app notification feed (`PortalNotification`).
///
/// The server sends no title or text: it sends what the notification is about
/// (a request, a ticket, an amount) and the screen words it in the user's
/// language from that structure. Names arrive masked; they are shown as given.
class InAppNotification extends Equatable {
  const InAppNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.relatedRequestId,
    this.relatedEntityId,
    this.referenceCode,
    this.serviceName,
    this.travelerLabel,
    this.amountCents,
    this.currency,
    this.ticketSubject,
  });

  final String id;

  /// The server's `eventType` when the app knows it, else its `kind`, else unknown.
  final NotificationEventType type;
  final DateTime createdAt;
  final bool isRead;

  /// Set when tapping this notification should open a request.
  final String? relatedRequestId;

  /// The ticket this is about (`ticketId`); null = nothing to open.
  final String? relatedEntityId;

  /// The request's reference code (like `SB-20481`).
  final String? referenceCode;
  final String? serviceName;

  /// The traveler as the server shows them (masked when it says so).
  final String? travelerLabel;
  final int? amountCents;
  final String? currency;
  final String? ticketSubject;

  InAppNotification copyWith({bool? isRead}) => InAppNotification(
        id: id,
        type: type,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        relatedRequestId: relatedRequestId,
        relatedEntityId: relatedEntityId,
        referenceCode: referenceCode,
        serviceName: serviceName,
        travelerLabel: travelerLabel,
        amountCents: amountCents,
        currency: currency,
        ticketSubject: ticketSubject,
      );

  @override
  List<Object?> get props => [
        id,
        type,
        createdAt,
        isRead,
        relatedRequestId,
        relatedEntityId,
        referenceCode,
        serviceName,
        travelerLabel,
        amountCents,
        currency,
        ticketSubject,
      ];
}

/// One page of the feed with the server's unread total for the whole inbox.
class NotificationsPage extends Equatable {
  const NotificationsPage({required this.items, required this.unreadCount, required this.total, required this.hasMore});

  final List<InAppNotification> items;
  final int unreadCount;
  final int total;
  final bool hasMore;

  @override
  List<Object?> get props => [items, unreadCount, total, hasMore];
}
