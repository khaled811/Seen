import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/enums.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

/// The signed-in agent's position; null when there is no session in scope (tests,
/// pre-sign-in) or the user is not an agent.
AgentPosition? currentAgentPosition(BuildContext context) {
  try {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.session.agentPosition : null;
  } on ProviderNotFoundException {
    return null;
  }
}

/// Branch managers and staff only look; the owner (and a session whose position the
/// server did not name) may change things. The server stays the authority and still
/// answers 403 for anyone who may not.
bool canManageAgency(BuildContext context) {
  final p = currentAgentPosition(context);
  return p == null || p == AgentPosition.owner || p == AgentPosition.unknown;
}
