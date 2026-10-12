import 'package:equatable/equatable.dart';

import '../../domain/entities/rite_mode.dart';

sealed class TawafEvent extends Equatable {
  const TawafEvent();

  @override
  List<Object?> get props => [];
}

/// Restore the persisted session (or start a fresh Tawaf) and load the duas.
class TawafStarted extends TawafEvent {
  const TawafStarted();
}

/// The big bottom button: records the next lap; after completion it moves on
/// (Tawaf -> Sa'i) or ends the rite (Sa'i).
class TawafPrimaryPressed extends TawafEvent {
  const TawafPrimaryPressed();
}

/// Undo the last lap. The UI has already asked the user to confirm.
class TawafUndoRequested extends TawafEvent {
  const TawafUndoRequested();
}

/// Switch between Tawaf and Sa'i, starting over at lap 1. The UI has already
/// asked for confirmation when progress would be lost.
class TawafModeSelected extends TawafEvent {
  const TawafModeSelected(this.mode);

  final RiteMode mode;

  @override
  List<Object?> get props => [mode];
}

/// End the rite and forget the session. The UI has already confirmed.
class TawafEndRequested extends TawafEvent {
  const TawafEndRequested();
}
