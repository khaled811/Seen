import 'package:equatable/equatable.dart';

import 'service_definition.dart';
import 'traveler_info.dart';

/// A booking the agent started and saved to finish later (Figma REQ-01 … 04):
/// the service and every traveler's field values. Pure Dart; kept on the device.
class BookingDraft extends Equatable {
  const BookingDraft({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.category,
    required this.travelers,
    required this.updatedAt,
  });

  /// Drafts older than this (since their last edit) are deleted automatically.
  static const lifetime = Duration(days: 30);

  /// How many drafts one agent may keep.
  static const maxCount = 10;

  final String id;
  final String serviceId;
  final String serviceName;
  final ServiceCategory category;
  final List<TravelerInfo> travelers;
  final DateTime updatedAt;

  DateTime get expiresAt => updatedAt.add(lifetime);

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);

  /// Whole days left before it is deleted (0 on the last day), never negative.
  int daysLeft(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? 0 : left.inDays;
  }

  BookingDraft copyWith({List<TravelerInfo>? travelers, DateTime? updatedAt}) => BookingDraft(
        id: id,
        serviceId: serviceId,
        serviceName: serviceName,
        category: category,
        travelers: travelers ?? this.travelers,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [id, serviceId, serviceName, category, travelers, updatedAt];
}

/// The result of saving a draft.
enum SaveDraftResult { saved, limitReached }
