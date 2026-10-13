import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/feedback.dart' show SeenNotificationKind;
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../requests/presentation/bloc/requests_event.dart';
import '../../../requests/presentation/screens/request_detail_screen.dart';
import '../../domain/entities/in_app_notification.dart';
import '../bloc/notifications_bloc.dart';
import '../bloc/notifications_event.dart';
import '../bloc/notifications_state.dart';
import '../widgets/notification_kind_mapping.dart';

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
                    NotificationsInitial() || NotificationsLoading() => const Center(child: SeenLoader()),
                    NotificationsFailure(:final message) => _ErrorView(message: message),
                    NotificationsLoaded() => _LoadedView(state: state),
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
    final requestId = notification.relatedRequestId;
    if (requestId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => InjectionContainer.instance.createRequestsBloc()..add(RequestDetailRequested(requestId)),
          child: const RequestDetailScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final now = DateTime.now();
    final notifications = state.notifications;
    if (notifications.isEmpty) {
      return SeenEmptyState(
        iconAsset: SeenVectors.iconChat,
        title: l10n.notificationsEmptyTitle,
        message: l10n.notificationsEmptyMessage,
      );
    }
    final groups = {for (final g in NotificationGroup.values) g: <InAppNotification>[]};
    for (final n in notifications) {
      groups[notificationGroupOf(n.createdAt, now)]!.add(n);
    }
    String groupTitle(NotificationGroup g) => switch (g) {
          NotificationGroup.today => l10n.notificationsGroupToday,
          NotificationGroup.yesterday => l10n.notificationsGroupYesterday,
          NotificationGroup.earlier => l10n.notificationsGroupEarlier,
        };

    // Figma 17: group labels and cards share one column with 10 px between them.
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        for (final g in NotificationGroup.values)
          if (groups[g]!.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(top: g == NotificationGroup.today ? 0 : 10, bottom: 10),
              child: Text(groupTitle(g), style: t.label.copyWith(color: c.inkMuted)),
            ),
            for (final n in groups[g]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NotificationCard(notification: n, now: now, onTap: () => _openNotification(context, n)),
              ),
          ],
      ],
    );
  }
}

/// Figma "Notification": an 18 px card with a 40 px tinted icon tile, the title,
/// and a muted "reference · detail · time" line. Unread cards use the soft
/// violet gradient and a violet dot at the end.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.now, required this.onTap});

  final InAppNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  (String, Color) _icon() => switch (notification.type.toSeenKind) {
        SeenNotificationKind.approved => (SeenVectors.notifCheck, SeenRequestStatus.completed.colors.bg),
        SeenNotificationKind.wallet => (SeenVectors.notifWallet, SeenRequestStatus.completed.colors.bg),
        SeenNotificationKind.action || SeenNotificationKind.sla => (
            SeenVectors.notifAlert,
            SeenRequestStatus.actionRequired.colors.bg
          ),
        SeenNotificationKind.agent => (SeenVectors.notifAgents, SeenRequestStatus.newRequest.colors.bg),
        SeenNotificationKind.review || SeenNotificationKind.system => (
            SeenVectors.notifReview,
            SeenRequestStatus.underReview.colors.bg
          ),
      };

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    final unread = !notification.isRead;
    final (asset, tileColor) = _icon();
    final meta = [
      if (notification.relatedRequestId != null) SeenFormat.isolate(notification.relatedRequestId!),
      if (notification.body.isNotEmpty) notification.body,
      s.timeAgo(notification.createdAt, now: now),
    ].join(' · ');
    const radius = BorderRadius.all(SeenRadius.r18);
    return Semantics(
      button: true,
      container: true,
      label: '${unread ? '${s.unread}, ' : ''}${notification.title}. $meta',
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
                    decoration: BoxDecoration(color: tileColor, borderRadius: const BorderRadius.all(SeenRadius.r12)),
                    child: SizedBox(width: 40, height: 40, child: Center(child: SeenSvgIcon(asset, size: 20))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
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
