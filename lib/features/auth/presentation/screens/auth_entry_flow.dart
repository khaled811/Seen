import 'package:flutter/material.dart';

import 'agency_pending_approval_screen.dart';
import 'create_agency_account_screen.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

enum _EntryStep { welcome, login, createAgency, pendingApproval }

/// Unauthenticated entry: Welcome (02) → Login (03), or Welcome → Create agency
/// account (15) → Pending approval (16). Owns only the "which step is showing"
/// UI state; every auth outcome still comes from `AuthBloc` through the app's
/// auth gate.
///
/// [startOnLogin] opens straight on Login (used after a failed sign-in, so a
/// rejected password does not bounce the user back to Welcome). The system back
/// gesture returns one step toward Welcome.
class AuthEntryFlow extends StatefulWidget {
  const AuthEntryFlow({super.key, this.startOnLogin = false});

  final bool startOnLogin;

  @override
  State<AuthEntryFlow> createState() => _AuthEntryFlowState();
}

class _AuthEntryFlowState extends State<AuthEntryFlow> {
  late _EntryStep _step = widget.startOnLogin ? _EntryStep.login : _EntryStep.welcome;

  @override
  void didUpdateWidget(covariant AuthEntryFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startOnLogin && !oldWidget.startOnLogin) _step = _EntryStep.login;
  }

  void _go(_EntryStep step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _EntryStep.welcome,
      onPopInvoked: (didPop) {
        if (!didPop) _go(_EntryStep.welcome);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: switch (_step) {
          _EntryStep.welcome => WelcomeScreen(
              key: const ValueKey('auth-welcome'),
              onSignIn: () => _go(_EntryStep.login),
              onCreateAccount: () => _go(_EntryStep.createAgency),
            ),
          _EntryStep.login => LoginScreen(
              key: const ValueKey('auth-login'),
              onBack: () => _go(_EntryStep.welcome),
              onCreateAccount: () => _go(_EntryStep.createAgency),
            ),
          _EntryStep.createAgency => CreateAgencyAccountScreen(
              key: const ValueKey('auth-create-agency'),
              onBack: () => _go(_EntryStep.welcome),
              onSubmitted: () => _go(_EntryStep.pendingApproval),
            ),
          _EntryStep.pendingApproval => const AgencyPendingApprovalScreen(key: ValueKey('auth-pending')),
        },
      ),
    );
  }
}
