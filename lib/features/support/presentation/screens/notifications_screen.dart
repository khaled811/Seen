import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/filters.dart';
import '../../../../core/presentation/widgets/system_state.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/navigation/shell_tab_request.dart';
import '../../../requests/presentation/bloc/requests_event.dart';
import '../../../requests/presentation/screens/request_detail_screen.dart';
import '../../domain/entities/in_app_notification.dart';
import '../bloc/notifications_bloc.dart';
import '../bloc/notifications_event.dart';
import '../bloc/notifications_state.dart';
import '../widgets/notification_kind_mapping.dart';
import '../widgets/notification_text.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/widgets/loading/seen_windows.dart';
import 'support_tickets_screen.dart';
import 'ticket_detail_screen.dart';
import '../../../../core/utils/app_clock.dart';

/// Notifications center (Figma 17): chronological groups (today / yesterday /
/// earlier), unread markers, mark-all-read and deep links into a request.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createNotificationsBloc()..add(const NotificationsLoadRequested()),
      child: const NotificationsView(),
    );
  }
}

/// The screen body, split from [NotificationsScreen] so tests can provide
/// their own [NotificationsBloc].
class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SeenScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              BlocBuilder<NotificationsBloc, NotificationsState>(
                buildWhen: (previous, current) => current is NotificationsLoaded,
                builder: (context, state) {
                  final unread = state is NotificationsLoaded ? state.unreadCount : 0;
                  return SeenScreenHeader(
                    title: l10n.notificationsTitle,
                    subtitle: unread > 0 ? SeenStrings.of(context).unreadCount(unread) : null,
                    // Product decision: keep "Mark all as read" (not drawn in Figma).
                    trailing: SeenButton.ghost(
                      label: l10n.notificationsMarkAllReadAction,
                      size: SeenButtonSize.small,
                      onPressed: unread > 0
                          ? () => context.read<NotificationsBloc>().add(const NotificationsMarkAllReadRequested())
                          : null,
                    ),
                  );
                },
              ),
              Expanded(
                child: BlocBuilder<NotificationsBloc, NotificationsState>(
                  builder: (context, state) => switch (state) {
                    NotificationsInitial() || NotificationsLoading() => SeenCardsSkeleton(label: SeenStrings.of(context).loadingLabel),
                    NotificationsFailure(:final message, :final failure) =>
                      _ErrorView(message: failureTextOr(AppLocalizations.of(context)!, failure, message)),
                    NotificationsLoaded() => Column(
                        children: [
                          _FilterChips(unreadOnly: state.unreadOnly),
                          if (state.filterLoading) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Center(child: SeenWindows(size: 6))),
                          Expanded(child: _LoadedView(state: state)),
                        ],
                      ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: SeenSpace.s3),
          SeenButton(
            label: l10n.retry,
            onPressed: () => context.read<NotificationsBloc>().add(const NotificationsLoadRequested()),
          ),
        ],
      ),
    );
  }
}

enum NotificationGroup { today, yesterday, earlier }

/// Calendar-day bucket of [createdAt] relative to [now] (local time).
NotificationGroup notificationGroupOf(DateTime createdAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return NotificationGroup.today;
  if (diff == 1) return NotificationGroup.yesterday;
  return NotificationGroup.earlier;
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final NotificationsLoaded state;

  void _openNotification(BuildContext context, InAppNotification notification) {
    if (!notification.isRead) {
      context.read<NotificationsBloc>().add(NotificationMarkReadRequested(notification.id));
    }
    final navigator = Navigator.of(context);
    switch (notificationTarget(notification)) {
      case null:
        return;
      case NotificationTarget.request:
        final requestId = notification.relatedRequestId!;
        navigator.push(
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) => InjectionContainer.instance.createRequestsBloc()..add(RequestDetailRequested(requestId)),
              child: const RequestDetailScreen(),
            ),
          ),
        );
      case NotificationTarget.ticket:
        navigator.push(
          MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: notification.relatedEntityId!)),
        );
      case NotificationTarget.support:
        navigator.push(MaterialPageRoute(builder: (_) => const SupportTicketsScreen()));
      case NotificationTarget.wallet:
      case NotificationTarget.agents:
        // These are tabs of the shell: leave this screen and ask the shell to show one.
        navigator.popUntil((route) => route.isFirst);
        ShellTabRequest.show(notificationTarget(notification) == NotificationTarget.wallet ? 2 : 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final now = AppClock.now();
    final notifications = state.visible;
    if (notifications.isEmpty && state.unreadOnly) {
      // Everything is read: say so (Figma NOTIF-01) instead of an empty feed.
      return const _AllReadState();
    }
    if (notifications.isEmpty) {
      return SeenEmptyState(
        iconAsset: SeenVectors.iconChat,
        title: l10n.notificationsEmptyTitle,
        message: l10n.notificationsEmptyMessage,
      );
    }
    String groupTitle(NotificationGroup g) => switch (g) {
          NotificationGroup.today => l10n.notificationsGroupToday,
          NotificationGroup.yesterday => l10n.notificationsGroupYesterday,
          NotificationGroup.earlier => l10n.notificationsGroupEarlier,
        };

    // Group headers and cards in one flat, lazily built column (Figma 17: 10 px
    // between them). A trailing row asks for the next page, or offers a retry.
    final rows = <Object>[];
    NotificationGroup? lastGroup;
    for (final n in notifications) {
      final group = notificationGroupOf(n.createdAt, now);
      if (group != lastGroup) {
        rows.add(group);
        lastGroup = group;
      }
      rows.add(n);
    }
    if (state.hasMore) rows.add(state.loadMoreFailed ? _RetryRow.instance : _LoadMoreRow.instance);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is NotificationGroup) {
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 10, bottom: 10),
            child: Text(groupTitle(row), style: t.label.copyWith(color: c.inkMuted)),
          );
        }
        if (row is InAppNotification) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NotificationCard(notification: row, now: now, onTap: () => _openNotification(context, row)),
          );
        }
        if (row is _RetryRow) {
          return Center(
            child: SeenTextLink(
              label: l10n.retry,
              onTap: () => context.read<NotificationsBloc>().add(const NotificationsLoadMoreRequested()),
            ),
          );
        }
        return const _LoadMoreTrigger();
      },
    );
  }
}

class _RetryRow {
  const _RetryRow._();
  static const instance = _RetryRow._();
}

class _LoadMoreRow {
  const _LoadMoreRow._();
  static const instance = _LoadMoreRow._();
}

/// Asks for the next page once it is built (the end of the lazy list).
class _LoadMoreTrigger extends StatefulWidget {
  const _LoadMoreTrigger();

  @override
  State<_LoadMoreTrigger> createState() => _LoadMoreTriggerState();
}

class _LoadMoreTriggerState extends State<_LoadMoreTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsBloc>().add(const NotificationsLoadMoreRequested());
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: SeenWindows(size: 8)));
}

/// Figma "Notification": an 18 px card with a 40 px tinted icon tile, the title,
/// and a muted "reference · detail · time" line. Unread cards use the soft
/// violet gradient and a violet dot at the end.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.now, required this.onTap});

  final InAppNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    final unread = !notification.isRead;
    final visual = notification.type.visual;
    final target = notificationTarget(notification);
    final hint = notification.type.hint(s);
    final title = NotificationText.title(s, notification);
    final detail = NotificationText.detail(notification);
    final meta = [
      if (detail.isNotEmpty) detail,
      s.timeAgo(notification.createdAt, now: now),
    ].join(' · ') + (target != null && hint.isNotEmpty ? ' → $hint' : '');
    const radius = BorderRadius.all(SeenRadius.r18);
    return Semantics(
      button: true,
      container: true,
      label: '${unread ? '${s.unread}, ' : ''}$title. $meta',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: unread ? SeenBrand.gradientSoft : null,
          color: unread ? null : c.card,
          borderRadius: radius,
          border: Border.all(color: c.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: visual.tone.colors.bg, borderRadius: const BorderRadius.all(SeenRadius.r12)),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(child: Icon(visual.icon, size: 20, color: visual.tone.colors.fg)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: unread ? t.bodyStrong.copyWith(color: c.ink) : t.body.copyWith(color: c.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (target != null) ...[
                    Icon(SeenIcons.forward(context), size: 16, color: c.inkMuted),
                    const SizedBox(width: 6),
                  ],
                  SizedBox(
                    width: 8,
                    height: 8,
                    child: unread
                        ? const DecoratedBox(
                            decoration: BoxDecoration(color: SeenBrand.violet, shape: BoxShape.circle),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Unread" and "All" (Figma NOTIF-01). The choice lives in the bloc.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.unreadOnly});

  final bool unreadOnly;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SeenSegmentChips(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        items: [SeenSegment(label: s.unreadFilter), SeenSegment(label: s.allFilter)],
        selectedIndex: unreadOnly ? 0 : 1,
        onSelected: (i) => context.read<NotificationsBloc>().add(NotificationsFilterChanged(unreadOnly: i == 0)),
      ),
    );
  }
}

class _AllReadState extends StatelessWidget {
  const _AllReadState();

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: SeenSystemMessage(
          illustration: SeenSystemIllustration(icon: SeenIcons.bell),
          title: s.noUnreadTitle,
          body: s.noUnreadBody,
        ),
      ),
    );
  }
}
