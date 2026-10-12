import 'package:equatable/equatable.dart';

import '../../domain/entities/dashboard_snapshot.dart';
import '../../domain/entities/day_prayers.dart';

sealed class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

/// [next] is derived from the clock; the state only changes (and the UI only
/// rebuilds) when the countdown minute or the upcoming prayer changes.
class DashboardLoaded extends DashboardState {
  const DashboardLoaded({required this.snapshot, required this.next});

  final DashboardSnapshot snapshot;
  final NextPrayer next;

  @override
  List<Object?> get props => [snapshot, next];
}

class DashboardFailure extends DashboardState {
  const DashboardFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
