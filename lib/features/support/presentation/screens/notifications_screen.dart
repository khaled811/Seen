import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/feedback.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/segmented_control.dart';
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
              SeenScreenHeader(
                title: l10n.notificationsTitle,
                trailing: BlocBuilder<NotificationsBloc, NotificationsState>(
                  buildWhen: (previous, current) => current is NotificationsLoaded,
                  builder: (context, state) {
                    final hasUnread = state is NotificationsLoaded && state.unreadCount > 0;
                    return SeenButton.ghost(
                      label: l10n.notificationsMarkAllReadAction,
                      size: SeenButtonSize.small,
                      onPressed: hasUnread
                          ? () => context.read<NotificationsBloc>().add(const NotificationsMarkAllReadRequested())
                          : null,
                    );
                  },
                ),
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

enum _ReadFilter { all, unread }

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

class _LoadedView extends StatefulWidget {
  const _LoadedView({required this.state});

  final NotificationsLoaded state;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  _ReadFilter _filter = _ReadFilter.all;

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
    final unread = widget.state.unreadCount;
    final now = DateTime.now();
    final notifications = widget.state.notifications.where((n) => switch (_filter) {
          _ReadFilter.all => true,
          _ReadFilter.unread => !n.isRead,
        }).toList();
    final groups = {for (final g in NotificationGroup.values) g: <InAppNotification>[]};
    for (final n in notifications) {
      groups[notificationGroupOf(n.createdAt, now)]!.add(n);
    }
    String groupTitle(NotificationGroup g) => switch (g) {
          NotificationGroup.today => l10n.notificationsGroupToday,
          NotificationGroup.yesterday => l10n.notificationsGroupYesterday,
          NotificationGroup.earlier => l10n.notificationsGroupEarlier,
        };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, SeenSpace.s2, 20, SeenSpace.s2),
          child: SeenSegmentedControl(
            labels: [
              l10n.walletFilterAll,
              unread > 0
                  ? '${l10n.notificationsUnreadFilter} (${SeenStrings.of(context).numeral(unread)})'
                  : l10n.notificationsUnreadFilter,
            ],
            selectedIndex: _ReadFilter.values.indexOf(_filter),
            onSelected: (i) => setState(() => _filter = _ReadFilter.values[i]),
          ),
        ),
        Expanded(
          child: notifications.isEmpty
              ? SeenEmptyState(
                  iconAsset: SeenVectors.iconChat,
                  title: l10n.notificationsEmptyTitle,
                  message: l10n.notificationsEmptyMessage,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, SeenSpace.s2, 20, 32),
                  children: [
                    for (final g in NotificationGroup.values)
                      if (groups[g]!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: SeenSpace.s2),
                          child: Text(groupTitle(g), style: t.label.copyWith(color: c.inkMuted)),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: const BorderRadius.all(SeenRadius.r22),
                            border: Border.all(color: c.border),
                            boxShadow: SeenShadows.card,
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(SeenRadius.r22),
                            child: Column(
                              children: [
                                for (var i = 0; i < groups[g]!.length; i++) ...[
                                  if (i > 0) Divider(height: 1, color: c.border),
                                  _tile(context, groups[g]![i]),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, InAppNotification n) => SeenNotificationTile(
        kind: n.type.toSeenKind,
        title: n.title,
        body: n.body,
        time: SeenFormat.isolate('${SeenFormat.date(n.createdAt)} ${SeenFormat.time(n.createdAt)}'),
        reference: n.relatedRequestId,
        unread: !n.isRead,
        onTap: () => _openNotification(context, n),
      );
}
