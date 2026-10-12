import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// One entry in the in-app notification feed.
class InAppNotification extends Equatable {
  const InAppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.relatedRequestId,
  });

  final String id;
  final NotificationEventType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Set when tapping this notification should deep-link to a request
  /// (e.g. a status update or SLA warning).
  final String? relatedRequestId;

  InAppNotification copyWith({bool? isRead}) => InAppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        relatedRequestId: relatedRequestId,
      );

  @override
  List<Object?> get props =>
      [id, type, title, body, createdAt, isRead, relatedRequestId];
}
