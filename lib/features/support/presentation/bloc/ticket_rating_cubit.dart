// Rating a resolved or closed ticket (design/gaps SUP-06): pick 1-5 stars, send once, then the
// card is locked. The server has no field that says a ticket was rated, so a ticket that was
// rated before only shows it when the person tries again (`already_rated`).
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/repositories/ticket_rating_repository.dart';

enum TicketRatingIssue { failed, notResolved, offline }

class TicketRatingState extends Equatable {
  const TicketRatingState({this.stars = 0, this.sending = false, this.done = false, this.issue});

  final int stars;
  final bool sending;

  /// The rating is in (sent now, or the server said it already was): stars locked.
  final bool done;
  final TicketRatingIssue? issue;

  @override
  List<Object?> get props => [stars, sending, done, issue];
}

class TicketRatingCubit extends Cubit<TicketRatingState> {
  TicketRatingCubit(this._repository, {required this.ticketId}) : super(const TicketRatingState());

  final TicketRatingRepository _repository;
  final String ticketId;

  void select(int stars) {
    if (state.sending || state.done || stars < 1 || stars > 5) {
      return;
    }
    emit(TicketRatingState(stars: stars));
  }

  /// A second tap while sending is ignored; the chosen stars are kept on failure.
  Future<void> submit() async {
    if (state.sending || state.done || state.stars == 0) {
      return;
    }
    emit(TicketRatingState(stars: state.stars, sending: true));
    final result = await _repository.rate(ticketId, state.stars);
    if (isClosed) {
      return;
    }
    result.fold(
      (failure) {
        if (failure is ServerFailure && failure.code == 'already_rated') {
          emit(TicketRatingState(stars: state.stars, done: true));
          return;
        }
        emit(TicketRatingState(
          stars: state.stars,
          issue: switch (failure) {
            NetworkFailure() => TicketRatingIssue.offline,
            ServerFailure(code: 'ticket_not_resolved') => TicketRatingIssue.notResolved,
            _ => TicketRatingIssue.failed,
          },
        ));
      },
      (_) => emit(TicketRatingState(stars: state.stars, done: true)),
    );
  }
}
