import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/feedback.dart';
import '../../../../core/presentation/widgets/filters.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../requests/presentation/bloc/requests_event.dart';
import '../../../requests/presentation/screens/request_detail_screen.dart';
import '../../domain/entities/in_app_notification.dart';
import '../bloc/notifications_bloc.dart';
import '../bloc/notifications_event.dart';
import '../bloc/notifications_state.dart';
import '../widgets/notification_kind_mapping.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createNotificationsBloc()
        ..add(const NotificationsLoadRequested()),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SeenTopBar.inner(
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
      body: BlocBuilder<NotificationsBloc, NotificationsState>(
        builder: (context, state) {
          return switch (state) {
            NotificationsInitial() || NotificationsLoading() =>
              const Center(child: SeenLoader()),
            NotificationsFailure(:final message) => _ErrorView(message: message),
            NotificationsLoaded() => _LoadedView(state: state),
          };
        },
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
          create: (_) => InjectionContainer.instance.createRequestsBloc()
            ..add(RequestDetailRequested(requestId)),
          child: const RequestDetailScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notifications = widget.state.notifications.where((n) => switch (_filter) {
          _ReadFilter.all => true,
          _ReadFilter.unread => !n.isRead,
        }).toList();

    return Column(
      children: [
        const SizedBox(height: SeenSpace.s2),
        SeenSegmentChips(
          items: [
            SeenSegment(label: l10n.walletFilterAll),
            SeenSegment(
              label: l10n.notificationsUnreadFilter,
              count: widget.state.unreadCount > 0 ? widget.state.unreadCount : null,
            ),
          ],
          selectedIndex: _ReadFilter.values.indexOf(_filter),
          onSelected: (i) => setState(() => _filter = _ReadFilter.values[i]),
        ),
        const SizedBox(height: SeenSpace.s2),
        Expanded(
          child: notifications.isEmpty
              ? Center(child: Text(l10n.notificationsEmptyMessage))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(SeenSpace.s4),
                  child: SeenListGroup(children: [
                    for (final notification in notifications)
                      SeenNotificationTile(
                        kind: notification.type.toSeenKind,
                        title: notification.title,
                        body: notification.body,
                        time: SeenFormat.isolate(
                            '${SeenFormat.date(notification.createdAt)} ${SeenFormat.time(notification.createdAt)}'),
                        reference: notification.relatedRequestId,
                        unread: !notification.isRead,
                        onTap: () => _openNotification(context, notification),
                      ),
                  ]),
                ),
        ),
      ],
    );
  }
}
