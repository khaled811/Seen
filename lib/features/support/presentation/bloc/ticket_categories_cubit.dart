// The categories offered for a new ticket (design/gaps SUP-07). «Other» is always there and
// always last: when the list cannot be loaded it is all there is, so a ticket can still be opened.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ticket_category_option.dart';
import '../../domain/repositories/ticket_categories_repository.dart';

class TicketCategoriesState extends Equatable {
  const TicketCategoriesState({this.loading = true, this.options = const [], this.failed = false});

  final bool loading;

  /// The server's categories, without «Other».
  final List<TicketCategoryOption> options;
  final bool failed;

  @override
  List<Object?> get props => [loading, options, failed];
}

class TicketCategoriesCubit extends Cubit<TicketCategoriesState> {
  TicketCategoriesCubit(this._repository) : super(const TicketCategoriesState());

  final TicketCategoriesRepository _repository;

  Future<void> load() async {
    emit(const TicketCategoriesState());
    final result = await _repository.list();
    if (isClosed) {
      return;
    }
    result.fold(
      (_) => emit(const TicketCategoriesState(loading: false, failed: true)),
      // The server's own catch-all is moved out of the list: «Other» is added once, last.
      (all) => emit(TicketCategoriesState(loading: false, options: [for (final o in all) if (!o.isOther) o])),
    );
  }
}
