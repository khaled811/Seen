import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/feature_flags.dart';
import 'core/di/injection_container.dart';
import 'core/localization/locale_cubit.dart';
import 'core/presentation/foundation/seen_icons.dart';
import 'core/presentation/foundation/seen_strings.dart';
import 'core/presentation/widgets/loader.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_cubit.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/otp_verification_screen.dart';
import 'features/home/presentation/screens/agent_shell.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/agents/presentation/screens/sub_agents_list_screen.dart';
import 'features/requests/presentation/screens/requests_dashboard_screen.dart';
import 'features/spiritual/presentation/shell/agent_tab.dart';
import 'features/spiritual/presentation/shell/mode_shell.dart';
import 'features/wallet/presentation/screens/wallet_screen.dart';

/// App root: owns the top-level [LocaleCubit], [ThemeModeCubit] and
/// [AuthBloc] and wires them into [MaterialApp].
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LocaleCubit()),
        BlocProvider(create: (_) => ThemeModeCubit()),
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
                home: const _AuthGate(),
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
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthInitial() || AuthLoading() => const _SplashScreen(),
          AuthOtpRequired(:final resendCooldownSeconds) =>
            OtpVerificationScreen(resendCooldownSeconds: resendCooldownSeconds),
          AuthFailure(stage: AuthFailureStage.otp, :final challengeToken)
              when challengeToken != null =>
            const OtpVerificationScreen(resendCooldownSeconds: 0),
          AuthAuthenticated(:final session) when !kEnableSpiritualHub =>
            AgentShell(session: session),
          AuthAuthenticated(:final session) =>
            ModeShell(
              agentHome: HomeScreen(session: session),
              agentTabs: _agentTabs(context),
              onAccount: showAccountSheet,
            ),
          AuthUnauthenticated() || AuthFailure() => const LoginScreen(),
        };
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: SeenLoader()));
  }
}
