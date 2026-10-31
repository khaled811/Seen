// The number of support tickets with replies the agent has not read (design/gaps SUP-08), for
// the badge on Home. Read when the app opens a screen that shows it, when the app comes back to
// the foreground, and after a ticket is read; it is emptied when the session ends.
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/unread_tickets_repository.dart';

class UnreadTicketsCubit extends Cubit<int> {
  UnreadTicketsCubit(this._repository) : super(0);

  final UnreadTicketsRepository _repository;
  bool _busy = false;

  /// Best effort: a failed read keeps the last number and never blocks the screen.
  Future<void> refresh() async {
    if (_busy) {
      return;
    }
    _busy = true;
    final result = await _repository.count();
    _busy = false;
    if (isClosed) {
      return;
    }
    result.fold((_) {}, (count) {
      if (count != state) {
        emit(count < 0 ? 0 : count);
      }
    });
  }

  /// The session ended: the next person must not see this number.
  void clear() => emit(0);
}
