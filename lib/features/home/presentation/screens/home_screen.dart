import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/balance_card.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/presentation/widgets/promo_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/service_tile.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/presentation/widgets/loading/seen_refresh.dart';
import '../../../../core/presentation/widgets/loading/seen_wait_policy.dart';
import '../../../ads/domain/entities/ad_banner.dart';
import '../../../ads/presentation/bloc/home_banner_cubit.dart';
import '../../../agents/presentation/screens/sub_agents_list_screen.dart';
import '../../../profile/presentation/screens/team_screen.dart';
import '../../../wallet/presentation/screens/wallet_screen.dart';
import '../../../services/domain/entities/service_definition.dart'
    show ServiceCategory;
import '../../../services/presentation/widgets/service_card_copy.dart';
import '../bloc/home_services_cubit.dart';
import '../../../manifest/data/services/external_url_opener.dart';
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
import '../../../wallet/presentation/widgets/wallet_balance_widgets.dart';
import '../../../auth/domain/entities/role_permissions.dart';
import '../../../profile/presentation/widgets/session_role.dart';
import 'account_screen.dart';
import 'role_home_screen.dart';
import '../../../profile/presentation/widgets/profile_photo.dart';
import '../../../support/presentation/widgets/support_unread_badge.dart';
import '../../../../core/utils/app_clock.dart';

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
    // Branch managers and staff get their own home (Figma ROLE-01); it needs no wallet.
    final permissions = RolePermissions.fromSession(session);
    if (permissions.isRestricted) {
      return RoleHomeScreen(position: session.agentPosition!);
    }
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
        BlocProvider(
            create: (_) =>
                InjectionContainer.instance.createHomeBannerCubit()..load()),
        BlocProvider(
            create: (_) =>
                InjectionContainer.instance.createHomeServicesCubit()..load()),
      ],
      child: _HomeView(session: session),
    );
  }
}

const _gutter = 14.0;

/// Figma 05: 22 px above and below a section title.
const _sectionPadding = EdgeInsets.symmetric(vertical: 22);

Future<void> _openServices(BuildContext context) async {
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ServiceSelectionScreen()));
  if (!context.mounted) return;
  context.read<RequestsBloc>().add(const RequestsLoadRequested());
  context.read<WalletBloc>().add(const WalletLoadRequested());
}

/// Follows an ad's button: an `https` link outside the app, or one of the app's own screens.
void _openAd(BuildContext context, AdBanner ad) {
  final destination = ad.internalDestination;
  if (destination == null) {
    unawaited(launchExternalUrl(ad.openableLink.toString()));
    return;
  }
  switch (destination) {
    case AdDestination.services:
      unawaited(_openServices(context));
    case AdDestination.requests:
      unawaited(_openRequests(context));
    case AdDestination.wallet:
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const WalletScreen()));
    case AdDestination.tickets:
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const SupportTicketsScreen()));
    case AdDestination.subAgents:
      Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SubAgentsListScreen()));
    case AdDestination.team:
      Navigator.of(context).push(TeamScreen.route());
  }
}

Future<void> _openRequests(BuildContext context) async {
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const RequestsDashboardScreen()));
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
          child: SeenRefresh(
            onRefresh: () async {
              context.read<WalletBloc>().add(const WalletLoadRequested());
              context
                  .read<NotificationsBloc>()
                  .add(const NotificationsLoadRequested());
              context.read<RequestsBloc>().add(const RequestsLoadRequested());
              unawaited(context.read<HomeBannerCubit>().load());
              unawaited(context.read<HomeServicesCubit>().load());
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  _gutter, SeenSpace.s3, _gutter, SeenSpace.s6),
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
                if (kShowHomePromoBanner)
                  BlocBuilder<HomeBannerCubit, HomeBannerState>(
                    buildWhen: (p, c) => p.ad != c.ad,
                    builder: (context, state) {
                      final ad = state.ad;
                      if (ad == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: SeenPromoBanner(
                          title: ad.title,
                          subtitle: ad.body,
                          actionLabel: ad.hasAction ? ad.ctaLabel : null,
                          onAction: ad.hasAction
                              ? () {
                                  context.read<HomeBannerCubit>().clicked();
                                  _openAd(context, ad);
                                }
                              : null,
                        ),
                      );
                    },
                  ),
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
              child: SizedBox(
                  width: 44,
                  height: 44,
                  // The person's photo when there is one; the glyph otherwise.
                  child: ProfilePhoto(
                      size: 44,
                      fallback: Center(
                          child: Icon(SeenIcons.user,
                              size: 22, color: c.primary)))),
            ),
          ),
        ),
        const SizedBox(width: SeenSpace.s2),
        Expanded(
            child: _SearchPill(
                hint: l10n.homeSearchHint,
                onTap: () => _openRequests(context))),
        const SizedBox(width: SeenSpace.s2),
        // The unread-support count sits on the button's corner (hidden at zero).
        SupportUnreadBadge(
            child: Semantics(
          button: true,
          label: l10n.homeQuickActionSupport,
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: const BoxDecoration(
                shape: BoxShape.circle, boxShadow: SeenShadows.card),
            child: Material(
              color: c.card,
              shape: CircleBorder(side: BorderSide(color: c.border)),
              child: InkWell(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const SupportTicketsScreen()))
                    .then((_) => SupportUnreadBadge.refresh()),
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                      child: SeenSvgIcon(SeenVectors.iconChat, size: 22)),
                ),
              ),
            ),
          ),
        )),
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
        decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(SeenRadius.full),
            boxShadow: SeenShadows.card),
        child: Material(
          color: c.card,
          shape: StadiumBorder(side: BorderSide(color: c.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: SeenSpace.s4),
                child: Row(
                  children: [
                    const SeenSvgIcon(SeenVectors.catalogSearch, size: 20),
                    const SizedBox(width: SeenSpace.s2),
                    Expanded(
                      child: Text(hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.body.copyWith(color: c.inkMuted)),
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
    final hour = AppClock.now().hour;
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
            // The server's own count (the whole account), not the loaded page's.
            final needAttention = state.attentionCount ??
                state.requests
                    .where((r) => r.status == RequestStatus.infoRequired)
                    .length;
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
        WalletInitial() || WalletLoading() => Semantics(
            label: l10n.loading,
            child: const ExcludeSemantics(
                child: SeenSkeletonGroup(child: SeenBalanceSkeleton())),
          ),
        WalletFailure(:final message, :final failure) => _InlineError(
            message: failureTextOr(l10n, failure, message),
            onRetry: () =>
                context.read<WalletBloc>().add(const WalletLoadRequested()),
          ),
        WalletLoaded(:final balance) when balance.isOverLimit =>
          SeenOverLimitCard(balance: balance),
        WalletLoaded(:final balance) => SeenBalanceCard(
            initiallyHidden: hideBalanceByDefault(context),
            hint: balance.isZero ? l10n.walletBalanceZeroHint : null,
            hiddenHint: l10n.walletBalanceHiddenHint,
            available: balance.availableCents / 100,
            hold: balance.holdCents / 100,
            creditLimit: balance.creditLimitCents / 100,
            caption: l10n.homeBalanceCaption,
            holdLabel: l10n.homeHoldChip,
            creditLimitLabel: l10n.homeCreditLimitChip,
            showSemanticLabel: l10n.balanceHiddenLabel,
            hideSemanticLabel: l10n.balanceShownLabel,
            // Top-up stays one tap away (Figma has no dedicated button on Home).
            onTap: () => Navigator.of(context)
                .push(TopUpRequestScreen.route(context.read<WalletBloc>())),
          ),
      },
    );
  }
}

/// Service shortcuts (Figma): the services the server puts first (`portalHome.services`),
/// up to six in two rows of three. Every tile opens the full service catalog. Nothing is
/// drawn while they load or when the server offers none: the "see all" link stays.
class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<HomeServicesCubit, HomeServicesState>(
      buildWhen: (a, b) => a.services != b.services,
      builder: (context, state) {
        final tiles = state.services.take(6).toList();
        if (tiles.isEmpty) return const SizedBox.shrink();
        Widget row(int from) => Row(
              children: [
                for (var i = from; i < from + 3; i++) ...[
                  if (i > from) const SizedBox(width: 10),
                  Expanded(
                    child: i < tiles.length
                        ? SeenServiceTile(
                            label: tiles[i].name,
                            iconAsset: ServiceCardCopy.forCategory(
                                    ServiceCategory.fromValue(
                                        tiles[i].category),
                                    l10n)
                                .iconAsset,
                            labelLines: 2,
                            onTap: () => _openServices(context),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            );
        return Column(children: [
          row(0),
          if (tiles.length > 3) ...[const SizedBox(height: 10), row(3)]
        ]);
      },
    );
  }
}

class _RecentRequests extends StatelessWidget {
  const _RecentRequests();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RequestsBloc, RequestsState>(
      builder: (context, state) => switch (state) {
        RequestsInitial() || RequestsLoading() => Padding(
            padding: const EdgeInsets.symmetric(vertical: SeenSpace.s6),
            child: SeenWaitPolicy.loading(
              loading: const SeenSkeletonGroup(
                child: Column(children: [
                  SeenCardSkeleton(),
                  SizedBox(height: 14),
                  SeenCardSkeleton()
                ]),
              ),
              onRetry: () => context
                  .read<RequestsBloc>()
                  .add(const RequestsLoadRequested()),
            ),
          ),
        RequestsFailure(:final message, :final failure) => Padding(
            padding: const EdgeInsets.symmetric(vertical: SeenSpace.s6),
            child: _InlineError(
              message: failureTextOr(
                  AppLocalizations.of(context)!, failure, message),
              onRetry: () => context
                  .read<RequestsBloc>()
                  .add(const RequestsLoadRequested()),
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
    final urgentCount =
        requests.where((r) => r.status == RequestStatus.infoRequired).length;

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
                subtitle: SeenStrings.of(context)
                    .travelerCount(request.travelerCount),
                status: request.status
                    .toSeenRequestStatus(slaDeadline: request.slaDeadline),
                progress: request.status.progress,
                reference: request.referenceId,
                dateLabel: SeenFormat.date(request.submittedAt),
                slaDeadline: request.status == RequestStatus.infoRequired
                    ? request.slaDeadline
                    : null,
                onTap: () {
                  final bloc = context.read<RequestsBloc>();
                  bloc.add(RequestDetailRequested(request.id));
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                          value: bloc, child: const RequestDetailScreen()),
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
          SeenButton.secondary(
              label: l10n.retry,
              size: SeenButtonSize.small,
              onPressed: onRetry),
        ],
      ),
    );
  }
}

/// Opens the account hub (Figma 14). Public so the shell's bottom bar can
/// open it too; the name predates the move from a sheet to a full page.
void showAccountSheet(BuildContext context) =>
    Navigator.of(context).push(AccountScreen.route());
