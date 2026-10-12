import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'login_screen.dart';
import 'welcome_screen.dart';

/// Unauthenticated entry: Welcome (02) → Login (03). Owns only the "which of
/// the two is showing" UI state; every auth outcome still comes from `AuthBloc`
/// through the app's auth gate.
///
/// [startOnLogin] opens straight on Login (used after a failed sign-in, so a
/// rejected password does not bounce the user back to Welcome). The system back
/// gesture on Login returns to Welcome.
class AuthEntryFlow extends StatefulWidget {
  const AuthEntryFlow({super.key, this.startOnLogin = false});

  final bool startOnLogin;

  @override
  State<AuthEntryFlow> createState() => _AuthEntryFlowState();
}

class _AuthEntryFlowState extends State<AuthEntryFlow> {
  late bool _showLogin = widget.startOnLogin;

  @override
  void didUpdateWidget(covariant AuthEntryFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startOnLogin && !oldWidget.startOnLogin) _showLogin = true;
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.comingSoon)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showLogin,
      onPopInvoked: (didPop) {
        if (!didPop) setState(() => _showLogin = false);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _showLogin
            ? LoginScreen(
                key: const ValueKey('auth-login'),
                onBack: () => setState(() => _showLogin = false),
                onCreateAccount: _comingSoon,
              )
            : WelcomeScreen(
                key: const ValueKey('auth-welcome'),
                onSignIn: () => setState(() => _showLogin = true),
                onCreateAccount: _comingSoon,
              ),
      ),
    );
  }
}
