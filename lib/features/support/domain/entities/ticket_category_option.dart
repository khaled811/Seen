import 'package:equatable/equatable.dart';

/// A category the person may pick for a new ticket (`ticketCategories`), named in the app language.
class TicketCategoryOption extends Equatable {
  const TicketCategoryOption({required this.code, required this.name, this.sortOrder = 0});

  /// The server's code, sent as `openGeneralTicket(category)`.
  final String code;
  final String name;
  final int sortOrder;

  /// The catch-all every list ends with; it is also the one the server defaults to.
  static const otherCode = 'general';

  bool get isOther => code == otherCode;

  @override
  List<Object?> get props => [code, name, sortOrder];
}
