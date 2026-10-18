import 'package:equatable/equatable.dart';

/// How a margin is expressed.
enum MarginKind {
  /// A fixed amount in USD cents added per traveler.
  fixed,

  /// A share of the service price, in basis points (3% = 300).
  percent,
}

/// The margin the agency adds to one service for its sub-agents (Figma ACC-02).
class ServiceMargin extends Equatable {
  const ServiceMargin({
    required this.serviceId,
    required this.serviceName,
    required this.kind,
    required this.value,
    required this.editable,
    this.iconKey,
  });

  final String serviceId;
  final String serviceName;
  final MarginKind kind;

  /// Cents for [MarginKind.fixed], basis points for [MarginKind.percent].
  final int value;

  /// false = set by Jubari, shown read-only (e.g. flight booking).
  final bool editable;

  /// Lets the screen pick an icon (`visa`, `entry`, `flight`...); null = generic.
  final String? iconKey;

  ServiceMargin withValue(int v) => ServiceMargin(
        serviceId: serviceId,
        serviceName: serviceName,
        kind: kind,
        value: v,
        editable: editable,
        iconKey: iconKey,
      );

  @override
  List<Object?> get props => [serviceId, serviceName, kind, value, editable, iconKey];
}

/// One past change ("Saudi visa: 8 -> 10 USD, 1 Oct, Majd").
class MarginChange extends Equatable {
  const MarginChange({
    required this.serviceName,
    required this.kind,
    required this.from,
    required this.to,
    required this.at,
    required this.by,
  });

  final String serviceName;
  final MarginKind kind;
  final int from;
  final int to;
  final DateTime at;
  final String by;

  @override
  List<Object?> get props => [serviceName, kind, from, to, at, by];
}

class MarginsOverview extends Equatable {
  const MarginsOverview({required this.margins, this.history = const []});

  final List<ServiceMargin> margins;

  /// Newest first.
  final List<MarginChange> history;

  @override
  List<Object?> get props => [margins, history];
}
