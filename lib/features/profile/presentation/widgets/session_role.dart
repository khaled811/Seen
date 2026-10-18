import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/preferences/balance_privacy_cubit.dart';
import '../../../auth/domain/entities/role_permissions.dart';
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

/// What the signed-in role may do (everything when there is no session in scope).
/// The server stays the authority and still answers 403 for anyone who may not.
RolePermissions permissionsOf(BuildContext context) => RolePermissions(currentAgentPosition(context));

/// The "hide the balance by default" setting; off when the app-wide cubit is not in scope.
bool hideBalanceByDefault(BuildContext context) {
  try {
    return context.watch<BalancePrivacyCubit>().state;
  } on ProviderNotFoundException {
    return false;
  }
}
