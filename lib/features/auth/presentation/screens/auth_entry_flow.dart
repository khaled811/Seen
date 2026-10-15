import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/entities/agency_registration.dart';
import 'agency_pending_approval_screen.dart';
import 'agency_registration_flow.dart';
import 'create_agency_account_screen.dart';
import 'forgot_password_flow.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

enum _EntryStep { welcome, login, createAgency, registration, pendingApproval, forgotPassword }

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

  /// The agency form, kept while the registration steps run so "back" and
  /// "edit number" return to a filled form. Held in memory only.
  AgencyRegistrationDraft? _draft;

  @override
  void didUpdateWidget(covariant AuthEntryFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startOnLogin && !oldWidget.startOnLogin) _step = _EntryStep.login;
  }

  void _go(_EntryStep step) => setState(() => _step = step);

  // No support channel exists before sign-in (see BACKEND_MIGRATION_GAPS.md).
  void _contactSupportSoon() => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.agencyPendingSupportNote)));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _EntryStep.welcome,
      onPopInvoked: (didPop) {
        // The forgot-password and registration flows handle their own back steps.
        if (didPop || _step == _EntryStep.forgotPassword || _step == _EntryStep.registration) return;
        _go(_EntryStep.welcome);
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
              onForgotPassword: () => _go(_EntryStep.forgotPassword),
              onCreateAccount: () => _go(_EntryStep.createAgency),
            ),
          _EntryStep.forgotPassword => ForgotPasswordFlow(
              key: const ValueKey('auth-forgot'),
              onExit: () => _go(_EntryStep.login),
              onCreateAccount: () => _go(_EntryStep.createAgency),
              onContactSupport: _contactSupportSoon,
            ),
          _EntryStep.createAgency => CreateAgencyAccountScreen(
              key: const ValueKey('auth-create-agency'),
              onBack: () => _go(_EntryStep.welcome),
              initial: _draft,
              onSubmitted: (draft) {
                _draft = draft;
                _go(_EntryStep.registration);
              },
            ),
          _EntryStep.registration => AgencyRegistrationFlow(
              key: const ValueKey('auth-registration'),
              draft: _draft!,
              onExit: () => _go(_EntryStep.createAgency),
              onCompleted: () {
                _draft = null;
                _go(_EntryStep.pendingApproval);
              },
              onSignIn: () => _go(_EntryStep.login),
            ),
          _EntryStep.pendingApproval => const AgencyPendingApprovalScreen(key: ValueKey('auth-pending')),
        },
      ),
    );
  }
}
