import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_images.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/quick_actions.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/theme_mode_cubit.dart';
import '../../../agents/presentation/screens/sub_agents_list_screen.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../requests/domain/entities/request_summary.dart';
import '../../../requests/presentation/bloc/requests_bloc.dart';
import '../../../requests/presentation/bloc/requests_event.dart';
import '../../../requests/presentation/bloc/requests_state.dart';
import '../../../requests/presentation/screens/request_detail_screen.dart';
import '../../../requests/presentation/screens/requests_dashboard_screen.dart';
import '../../../requests/presentation/widgets/request_status_seen_mapping.dart';
import '../../../requests/presentation/widgets/seen_request_card.dart';
import '../../../services/presentation/screens/service_selection_screen.dart';
import '../../../support/presentation/bloc/notifications_bloc.dart';
import '../../../support/presentation/bloc/notifications_event.dart';
import '../../../support/presentation/bloc/notifications_state.dart';
import '../../../support/presentation/screens/notifications_screen.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../../wallet/presentation/widgets/top_up_request_sheet.dart';
import '../../../wallet/presentation/widgets/wallet_card.dart';

/// Executive Dashboard — the authenticated home screen. Owns fresh
/// [WalletBloc], [NotificationsBloc] and [RequestsBloc] instances (none of
/// the three is a DI singleton) and composes the migrated Seen widget suite
/// around them.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session});

  final UserSession session;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => InjectionContainer.instance.createWalletBloc()
            ..add(const WalletLoadRequested()),
        ),
        BlocProvider(
          create: (_) => InjectionContainer.instance.createNotificationsBloc()
            ..add(const NotificationsLoadRequested()),
        ),
        BlocProvider(
          create: (_) => InjectionContainer.instance.createRequestsBloc()
            ..add(const RequestsLoadRequested()),
        ),
      ],
      child: _HomeView(session: session),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({required this.session});

  final UserSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: _HomeTopBar(session: session),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<WalletBloc>().add(const WalletLoadRequested());
          context.read<NotificationsBloc>().add(const NotificationsLoadRequested());
          context.read<RequestsBloc>().add(const RequestsLoadRequested());
        },
        child: ListView(
          padding: const EdgeInsets.all(SeenSpace.s4),
          children: [
            BlocBuilder<WalletBloc, WalletState>(
              builder: (context, state) => switch (state) {
                WalletInitial() || WalletLoading() => const Padding(
                    padding: EdgeInsets.symmetric(vertical: SeenSpace.s6),
                    child: Center(child: SeenLoader()),
                  ),
                WalletFailure(:final message) => _InlineError(
                    message: message,
                    onRetry: () => context.read<WalletBloc>().add(const WalletLoadRequested()),
                  ),
                WalletLoaded(:final balance) => SeenWalletCard(
                    available: balance.availableCents / 100,
                    hold: balance.holdCents / 100,
                    creditLimit: balance.creditLimitCents / 100,
                    onTopUp: () => showTopUpRequestSheet(context),
                    backgroundPattern: SeenImages.flightPattern,
                  ),
              },
            ),
            const SizedBox(height: SeenSpace.s4),
            BlocBuilder<RequestsBloc, RequestsState>(
              buildWhen: (previous, current) => current is RequestsLoaded,
              builder: (context, state) {
                final actionRequiredCount = state is RequestsLoaded
                    ? state.requests.where((r) => r.status == RequestStatus.infoRequired).length
                    : 0;
                return SeenQuickActionRow(children: [
                  SeenQuickAction(
                    icon: SeenIcons.passport,
                    label: l10n.homeQuickActionServices,
                    primary: true,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ServiceSelectionScreen()),
                      );
                      if (!context.mounted) return;
                      context.read<RequestsBloc>().add(const RequestsLoadRequested());
                      context.read<WalletBloc>().add(const WalletLoadRequested());
                    },
                  ),
                  SeenQuickAction(
                    icon: SeenIcons.list,
                    label: l10n.homeQuickActionRequests,
                    count: actionRequiredCount,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RequestsDashboardScreen()),
                      );
                      if (!context.mounted) return;
                      context.read<RequestsBloc>().add(const RequestsLoadRequested());
                    },
                  ),
                  SeenQuickAction(
                    icon: SeenIcons.users,
                    label: l10n.homeQuickActionSubAgents,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SubAgentsListScreen()),
                    ),
                  ),
                  SeenQuickAction(
                    icon: SeenIcons.headset,
                    label: l10n.homeQuickActionSupport,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SupportTicketsScreen()),
                    ),
                  ),
                  // A 5th tile — not one of the four flows the brief names,
                  // but the only remaining entry point to sign-out now that
                  // the old placeholder screen (which had its own AppBar
                  // action for it) is gone.
                  SeenQuickAction(
                    icon: SeenIcons.user,
                    label: l10n.homeQuickActionAccount,
                    onTap: () => showAccountSheet(context),
                  ),
                ]);
              },
            ),
            BlocBuilder<RequestsBloc, RequestsState>(
              builder: (context, state) => switch (state) {
                RequestsInitial() || RequestsLoading() => const Padding(
                    padding: EdgeInsets.symmetric(vertical: SeenSpace.s6),
                    child: Center(child: SeenLoader()),
                  ),
                RequestsFailure(:final message) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: SeenSpace.s6),
                    child: _InlineError(
                      message: message,
                      onRetry: () => context.read<RequestsBloc>().add(const RequestsLoadRequested()),
                    ),
                  ),
                RequestsLoaded(:final requests) => _RequestsFeed(requests: requests),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The account sheet (sign out). Public so the dual-mode shell's bottom bar
/// can open it too.
void showAccountSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final authBloc = context.read<AuthBloc>();
  showSeenSheet<void>(
    context: context,
    title: l10n.homeQuickActionAccount,
    builder: (sheetContext) => SeenButton.dangerOutline(
      label: l10n.accountSignOutAction,
      icon: SeenIcons.x,
      expand: true,
      onPressed: () {
        authBloc.add(const AuthLogoutRequested());
        Navigator.of(sheetContext).maybePop();
      },
    ),
  );
}

class _HomeTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeTopBar({required this.session});

  final UserSession session;

  @override
  Size get preferredSize => const Size.fromHeight(SeenSize.appBar);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      buildWhen: (previous, current) => current is NotificationsLoaded,
      builder: (context, notificationsState) {
        final unread = notificationsState is NotificationsLoaded ? notificationsState.unreadCount : 0;
        return BlocBuilder<ThemeModeCubit, ThemeMode>(
          builder: (context, mode) {
            final themeIcon = switch (mode) {
              ThemeMode.system => PhosphorIconsRegular.circleHalf,
              ThemeMode.light => PhosphorIconsRegular.sun,
              ThemeMode.dark => PhosphorIconsRegular.moon,
            };
            return SeenTopBar.home(
              company: l10n.appTitle,
              agentId: session.userId,
              unread: unread,
              onLanguage: () => context.read<LocaleCubit>().toggleLocale(),
              onNotifications: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
                if (!context.mounted) return;
                context.read<NotificationsBloc>().add(const NotificationsLoadRequested());
              },
              themeIcon: themeIcon,
              themeSemanticLabel: l10n.homeThemeToggleLabel,
              onThemeToggle: () => context.read<ThemeModeCubit>().toggleThemeMode(),
            );
          },
        );
      },
    );
  }
}

class _RequestsFeed extends StatelessWidget {
  const _RequestsFeed({required this.requests});

  final List<RequestSummary> requests;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = [...requests]..sort((a, b) {
        final aUrgent = a.status == RequestStatus.infoRequired;
        final bUrgent = b.status == RequestStatus.infoRequired;
        if (aUrgent != bUrgent) return aUrgent ? -1 : 1;
        return b.submittedAt.compareTo(a.submittedAt);
      });
    final top = sorted.take(5).toList();
    final urgentCount = requests.where((r) => r.status == RequestStatus.infoRequired).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeenSectionHeader(
          title: l10n.homeRecentRequestsTitle,
          count: urgentCount > 0 ? urgentCount : null,
          actionLabel: l10n.homeSeeAllAction,
          onAction: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RequestsDashboardScreen()),
            );
            if (!context.mounted) return;
            context.read<RequestsBloc>().add(const RequestsLoadRequested());
          },
        ),
        if (top.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: SeenSpace.s6),
            child: Center(child: Text(l10n.homeEmptyRequestsMessage)),
          )
        else
          for (final request in top)
            Padding(
              padding: const EdgeInsets.only(bottom: SeenSpace.s3),
              child: SeenRequestCard(
                reference: request.referenceId,
                service: request.serviceName,
                travelers: request.travelerCount,
                date: SeenFormat.date(request.submittedAt),
                status: request.status.toSeenStatus,
                slaDeadline: request.status == RequestStatus.infoRequired ? request.slaDeadline : null,
                amount: request.totalPriceCents / 100,
                onTap: () {
                  final bloc = context.read<RequestsBloc>();
                  bloc.add(RequestDetailRequested(request.id));
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: bloc,
                        child: const RequestDetailScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: SeenSpace.s3),
          FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
