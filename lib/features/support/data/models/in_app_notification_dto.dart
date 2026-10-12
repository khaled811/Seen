import '../../../../core/constants/enums.dart';
import '../../domain/entities/in_app_notification.dart';

/// Wire shape of one notification.
///
/// TODO(backend-contract): field names are placeholders pending the real
/// Seen Booking GraphQL schema.
class InAppNotificationDto {
  const InAppNotificationDto({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.type,
    this.relatedRequestId,
  });

  factory InAppNotificationDto.fromJson(Map<String, dynamic> json) => InAppNotificationDto(
        id: json['id'] as String,
        type: json['type'] as String?,
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isRead: json['isRead'] as bool,
        relatedRequestId: json['relatedRequestId'] as String?,
      );

  final String id;
  final String? type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedRequestId;

  InAppNotification toEntity() => InAppNotification(
        id: id,
        type: NotificationEventType.fromValue(type),
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: isRead,
        relatedRequestId: relatedRequestId,
      );
}
