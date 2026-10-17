import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/feature_flags.dart';
import 'core/di/injection_container.dart';
import 'core/presentation/connectivity/connectivity_shell.dart';
import 'core/localization/locale_cubit.dart';
import 'core/presentation/foundation/seen_icons.dart';
import 'core/presentation/foundation/seen_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_cubit.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/screens/session_expired_dialog.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/auth_entry_flow.dart';
import 'features/auth/presentation/screens/otp_verification_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/home/presentation/screens/agent_shell.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/agents/presentation/screens/sub_agents_list_screen.dart';
import 'features/requests/presentation/screens/requests_dashboard_screen.dart';
import 'features/spiritual/presentation/shell/agent_tab.dart';
import 'features/spiritual/presentation/shell/mode_shell.dart';
import 'features/wallet/presentation/screens/wallet_screen.dart';

/// Minimum cold-start splash time (Figma 01 is a brand moment, not a spinner).
const kSplashMinDuration = Duration(milliseconds: 1800);

/// App root: owns the top-level [LocaleCubit], [ThemeModeCubit] and
/// [AuthBloc] and wires them into [MaterialApp].
class App extends StatelessWidget {
  const App({super.key, this.splashMinDuration = kSplashMinDuration});

  /// How long the splash stays up on a cold start even if the session is
  /// restored sooner. Tests pass [Duration.zero].
  final Duration splashMinDuration;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LocaleCubit()),
        BlocProvider(create: (_) => ThemeModeCubit()),
        BlocProvider(create: (_) => InjectionContainer.instance.createConnectivityCubit()),
        BlocProvider(
            create: (_) => InjectionContainer.instance.createAuthBloc()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return BlocBuilder<ThemeModeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return MaterialApp(
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context)!.appTitle,
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: themeMode,
                debugShowCheckedModeBanner: false,
                builder: (context, child) => SeenConnectivityShell(child: child),
                home: _AuthGate(splashMinDuration: splashMinDuration),
              );
            },
          );
        },
      ),
    );
  }
}

/// Bottom-bar tabs of the agent workspace (after Home): requests, wallet and
/// sub-agents are pages inside the shell (the bar stays); account opens its
/// sheet.
List<AgentTab> _agentTabs(BuildContext context) {
  final nav = SeenStrings.of(context).nav;
  return [
    AgentTab(
      icon: SeenIcons.list,
      label: nav[1],
      builder: (_) => const RequestsDashboardScreen(),
    ),
    AgentTab(
      icon: SeenIcons.wallet,
      label: nav[2],
      builder: (_) => const WalletScreen(embedded: true),
    ),
    AgentTab(
      icon: SeenIcons.users,
      label: nav[3],
      builder: (_) => const SubAgentsListScreen(embedded: true),
    ),
    AgentTab(
      icon: SeenIcons.user,
      label: nav[4],
      onTap: showAccountSheet,
    ),
  ];
}

/// Picks the visible screen from [AuthState]. Temporary — replace with
/// proper named routes once real navigation/deep-linking is needed.
///
/// `AuthLoading` only shows the splash while the persisted session is being
/// restored (previous state `AuthInitial`). Later loading states (login, OTP
/// verify) keep the current screen mounted so its own button spinner shows and
/// the typed values survive a failed attempt.
class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.splashMinDuration});

  final Duration splashMinDuration;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  // Owned here, cancelled in dispose().
  Timer? _splashTimer;
  late bool _splashHeld = widget.splashMinDuration > Duration.zero;

  @override
  void initState() {
    super.initState();
    if (_splashHeld) {
      _splashTimer = Timer(widget.splashMinDuration, () {
        if (mounted) setState(() => _splashHeld = false);
      });
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_splashHeld) return const SplashScreen();
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous is! AuthSessionExpired && current is AuthSessionExpired,
      listener: (context, state) async {
        final bloc = context.read<AuthBloc>();
        await showSessionExpiredDialog(context);
        // Screens pushed above the gate would outlive the session: drop them,
        // then let the bloc clear the session and show Login.
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        bloc.add(const AuthSessionExpiredAcknowledged());
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (previous, current) =>
            !(current is AuthLoading && previous is! AuthInitial),
        builder: (context, state) {
          return switch (state) {
            AuthInitial() || AuthLoading() => const SplashScreen(),
            AuthOtpRequired(:final resendCooldownSeconds, :final identifier) =>
              OtpVerificationScreen(
                  resendCooldownSeconds: resendCooldownSeconds,
                  identifier: identifier),
            AuthFailure(stage: AuthFailureStage.otp, :final challengeToken)
                when challengeToken != null =>
              const OtpVerificationScreen(resendCooldownSeconds: 0),
            // Expired keeps the same shell under the dialog (AUTH-13).
            AuthAuthenticated(:final session) ||
            AuthSessionExpired(:final session) when !kEnableSpiritualHub =>
              AgentShell(session: session),
            AuthAuthenticated(:final session) ||
            AuthSessionExpired(:final session) =>
              ModeShell(
                agentHome: HomeScreen(session: session),
                agentTabs: _agentTabs(context),
                onAccount: showAccountSheet,
              ),
            AuthUnauthenticated(:final startOnLogin) =>
              AuthEntryFlow(startOnLogin: startOnLogin),
            // A rejected sign-in goes back to Login, not Welcome.
            AuthFailure() => const AuthEntryFlow(startOnLogin: true),
          };
        },
      ),
    );
  }
}
