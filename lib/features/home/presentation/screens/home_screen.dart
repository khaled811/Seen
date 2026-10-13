import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/balance_card.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/promo_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/service_tile.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../../requests/domain/entities/request_summary.dart';
import '../../../requests/presentation/bloc/requests_bloc.dart';
import '../../../requests/presentation/bloc/requests_event.dart';
import '../../../requests/presentation/bloc/requests_state.dart';
import '../../../requests/presentation/screens/request_detail_screen.dart';
import '../../../requests/presentation/screens/requests_dashboard_screen.dart';
import '../../../requests/presentation/widgets/request_status_seen_mapping.dart';
import '../../../requests/presentation/widgets/seen_request_summary_card.dart';
import '../../../services/presentation/screens/service_selection_screen.dart';
import '../../../support/presentation/bloc/notifications_bloc.dart';
import '../../../support/presentation/bloc/notifications_event.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../../wallet/presentation/screens/top_up_request_screen.dart';
import 'account_screen.dart';

/// Home dashboard (Figma 05): header, greeting, balance card, primary actions,
/// promo banner, services grid and the latest requests. Owns fresh
/// [WalletBloc], [NotificationsBloc] and [RequestsBloc] instances (none of the
/// three is a DI singleton).
///
/// Data not available from the backend yet is deliberately not invented: the
/// session carries no agency name, branch label or account status, so the
/// header shows the greeting only; the services grid and the promo banner are
/// static placeholders.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session});

  final UserSession session;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => InjectionContainer.instance.createWalletBloc()..add(const WalletLoadRequested()),
        ),
        BlocProvider(
          create: (_) => InjectionContainer.instance.createNotificationsBloc()..add(const NotificationsLoadRequested()),
        ),
        BlocProvider(
          create: (_) => InjectionContainer.instance.createRequestsBloc()..add(const RequestsLoadRequested()),
        ),
      ],
      child: _HomeView(session: session),
    );
  }
}

const _gutter = 14.0;

/// Figma 05: 22 px above and below a section title.
const _sectionPadding = EdgeInsets.symmetric(vertical: 22);

Future<void> _openServices(BuildContext context) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServiceSelectionScreen()));
  if (!context.mounted) return;
  context.read<RequestsBloc>().add(const RequestsLoadRequested());
  context.read<WalletBloc>().add(const WalletLoadRequested());
}

Future<void> _openRequests(BuildContext context) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestsDashboardScreen()));
  if (!context.mounted) return;
  context.read<RequestsBloc>().add(const RequestsLoadRequested());
}

class _HomeView extends StatelessWidget {
  const _HomeView({required this.session});

  final UserSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              context.read<WalletBloc>().add(const WalletLoadRequested());
              context.read<NotificationsBloc>().add(const NotificationsLoadRequested());
              context.read<RequestsBloc>().add(const RequestsLoadRequested());
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s3, _gutter, SeenSpace.s6),
              children: [
                const _HomeHeader(),
                const SizedBox(height: 16),
                const _Greeting(),
                const SizedBox(height: 24),
                const _BalanceSection(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SeenButton(
                        label: l10n.homeRequestServiceAction,
                        expand: true,
                        onPressed: () => _openServices(context),
                      ),
                    ),
                    const SizedBox(width: SeenSpace.s2),
                    Expanded(
                      child: SeenButton.secondary(
                        label: l10n.homeMyRequestsAction,
                        expand: true,
                        onPressed: () => _openRequests(context),
                      ),
                    ),
                  ],
                ),
                if (kShowHomePromoBanner) ...[
                  const SizedBox(height: 22),
                  SeenPromoBanner(
                    badge: l10n.promoBadge,
                    title: l10n.promoTitle,
                    subtitle: l10n.promoSubtitle,
                    actionLabel: l10n.promoAction,
                    onAction: () => _openServices(context),
                  ),
                ],
                SeenSectionHeader(
                  title: l10n.homeServicesTitle,
                  actionLabel: l10n.homeSeeAllAction,
                  onAction: () => _openServices(context),
                  padding: _sectionPadding,
                ),
                const _ServicesGrid(),
                const _RecentRequests(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma 05 "Top bar": avatar, search pill and a chat (support) button. The
/// bell that used to sit here is gone: notifications live in the Account tab.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    return Row(
      children: [
        // The session has no agency name, so the avatar carries a person glyph
        // instead of the initials Figma shows.
        Semantics(
          button: true,
          label: s.nav[4],
          excludeSemantics: true,
          child: Material(
            color: SeenBrand.violet10,
            shape: CircleBorder(side: BorderSide(color: c.borderStrong)),
            child: InkWell(
              onTap: () => showAccountSheet(context),
              customBorder: const CircleBorder(),
              child: SizedBox(width: 44, height: 44, child: Icon(SeenIcons.user, size: 22, color: c.primary)),
            ),
          ),
        ),
        const SizedBox(width: SeenSpace.s2),
        Expanded(child: _SearchPill(hint: l10n.homeSearchHint, onTap: () => _openRequests(context))),
        const SizedBox(width: SeenSpace.s2),
        Semantics(
          button: true,
          label: l10n.homeQuickActionSupport,
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: SeenShadows.card),
            child: Material(
              color: c.card,
              shape: CircleBorder(side: BorderSide(color: c.border)),
              child: InkWell(
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportTicketsScreen())),
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: SeenSvgIcon(SeenVectors.iconChat, size: 22)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Figma search pill. No search API exists yet, so it opens the requests
/// dashboard (where requests can be filtered) instead of an editable field.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(borderRadius: BorderRadius.all(SeenRadius.full), boxShadow: SeenShadows.card),
        child: Material(
          color: c.card,
          shape: StadiumBorder(side: BorderSide(color: c.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: SeenSpace.s4),
                child: Row(
                  children: [
                    const SeenSvgIcon(SeenVectors.catalogSearch, size: 20),
                    const SizedBox(width: SeenSpace.s2),
                    Expanded(
                      child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: type.body.copyWith(color: c.inkMuted)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l10n.homeGreetingMorning
        : hour < 17
            ? l10n.homeGreetingAfternoon
            : l10n.homeGreetingEvening;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: type.h2),
        BlocBuilder<RequestsBloc, RequestsState>(
          buildWhen: (previous, current) => current is RequestsLoaded,
          builder: (context, state) {
            if (state is! RequestsLoaded) return const SizedBox.shrink();
            final needAttention = state.requests.where((r) => r.status == RequestStatus.infoRequired).length;
            return Text(
              SeenStrings.of(context).attentionSummary(needAttention),
              style: type.body.copyWith(color: c.inkSecondary),
            );
          },
        ),
      ],
    );
  }
}

class _BalanceSection extends StatelessWidget {
  const _BalanceSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) => switch (state) {
        WalletInitial() || WalletLoading() => const SizedBox(height: 196, child: Center(child: SeenLoader())),
        WalletFailure(:final message) => _InlineError(
            message: message,
            onRetry: () => context.read<WalletBloc>().add(const WalletLoadRequested()),
          ),
        WalletLoaded(:final balance) => SeenBalanceCard(
            available: balance.availableCents / 100,
            hold: balance.holdCents / 100,
            creditLimit: balance.creditLimitCents / 100,
            caption: l10n.homeBalanceCaption,
            holdLabel: l10n.homeHoldChip,
            creditLimitLabel: l10n.homeCreditLimitChip,
            showSemanticLabel: l10n.balanceHiddenLabel,
            hideSemanticLabel: l10n.balanceShownLabel,
            // Top-up stays one tap away (Figma has no dedicated button on Home).
            onTap: () => Navigator.of(context).push(TopUpRequestScreen.route(context.read<WalletBloc>())),
          ),
      },
    );
  }
}

/// Six service shortcuts (Figma). Static placeholders: every tile opens the
/// full service catalog; "hotels" is shown as coming soon.
class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tiles = <({String label, String icon, bool soon})>[
      (label: l10n.serviceFlights, icon: SeenVectors.iconFlight, soon: false),
      (label: l10n.serviceEgyptEntry, icon: SeenVectors.iconEgyptEntry, soon: false),
      (label: l10n.serviceSaudiVisa, icon: SeenVectors.iconSaudiVisa, soon: false),
      (label: l10n.serviceIndiaVisa, icon: SeenVectors.iconIndiaVisa, soon: false),
      (label: l10n.serviceSecurityApproval, icon: SeenVectors.iconJordanSecurity, soon: false),
      (label: l10n.serviceHotels, icon: SeenVectors.iconHotel, soon: true),
    ];
    Widget row(int from) => Row(
          children: [
            for (var i = from; i < from + 3; i++) ...[
              if (i > from) const SizedBox(width: 10),
              Expanded(
                child: SeenServiceTile(
                  label: tiles[i].label,
                  iconAsset: tiles[i].icon,
                  soon: tiles[i].soon,
                  soonLabel: tiles[i].soon ? l10n.serviceSoonTag : null,
                  onTap: () => _openServices(context),
                ),
              ),
            ],
          ],
        );
    return Column(children: [row(0), const SizedBox(height: 10), row(3)]);
  }
}

class _RecentRequests extends StatelessWidget {
  const _RecentRequests();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestsBloc, RequestsState>(
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
    );
  }
}

class _RequestsFeed extends StatelessWidget {
  const _RequestsFeed({required this.requests});

  final List<RequestSummary> requests;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Urgent first, then newest; capped at 5 (this is a summary, not the list).
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
          title: l10n.homeLatestRequestsTitle,
          count: urgentCount > 0 ? urgentCount : null,
          actionLabel: l10n.homeSeeAllAction,
          onAction: () => _openRequests(context),
          padding: _sectionPadding,
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
              child: SeenRequestSummaryCard(
                title: request.serviceName,
                subtitle: SeenStrings.of(context).travelerCount(request.travelerCount),
                status: request.status.toSeenRequestStatus(slaDeadline: request.slaDeadline),
                progress: request.status.progress,
                reference: request.referenceId,
                dateLabel: SeenFormat.date(request.submittedAt),
                slaDeadline: request.status == RequestStatus.infoRequired ? request.slaDeadline : null,
                onTap: () {
                  final bloc = context.read<RequestsBloc>();
                  bloc.add(RequestDetailRequested(request.id));
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(value: bloc, child: const RequestDetailScreen()),
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
          SeenButton.secondary(label: l10n.retry, size: SeenButtonSize.small, onPressed: onRetry),
        ],
      ),
    );
  }
}

/// Opens the account hub (Figma 14). Public so the shell's bottom bar can
/// open it too; the name predates the move from a sheet to a full page.
void showAccountSheet(BuildContext context) =>
    Navigator.of(context).push(AccountScreen.route());
