import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ticket_category_option.dart';

/// The categories the caller may pick for a new ticket. The server already limits an agent to
/// the active, agent-usable general ones.
abstract interface class TicketCategoriesRepository {
  Future<Either<Failure, List<TicketCategoryOption>>> list();
}
