import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// One entry in a request's status-history timeline.
class RequestTimelineEntry extends Equatable {
  const RequestTimelineEntry({
    required this.status,
    required this.occurredAt,
    this.note,
  });

  final RequestStatus status;
  final DateTime occurredAt;
  final String? note;

  @override
  List<Object?> get props => [status, occurredAt, note];
}
