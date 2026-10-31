import 'package:equatable/equatable.dart';

/// A sub-agency's own request to be funded, waiting for its main agent's decision
/// (`pendingSubAgentTopUps`). Approving it moves the money out of the main agent's own
/// wallet. Pure Dart.
class SubAgentTopUp extends Equatable {
  const SubAgentTopUp({required this.id, required this.agentName, required this.amountCents, required this.createdAt, this.note = ''});

  final String id;
  final String agentName;
  final int amountCents;
  final DateTime createdAt;

  /// What the sub-agency wrote with the request.
  final String note;

  @override
  List<Object?> get props => [id, agentName, amountCents, createdAt, note];
}
