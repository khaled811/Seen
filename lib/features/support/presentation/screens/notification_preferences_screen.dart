// Notification preferences (Figma NOTIF-04): what to be told about, and quiet hours.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/components.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../auth/domain/entities/role_permissions.dart';
import '../../../profile/presentation/widgets/session_role.dart';
import '../../../system_status/domain/services/push_permission_service.dart';
import '../../../system_status/presentation/screens/push_permission_screen.dart';
import '../../domain/entities/notification_preferences.dart';
import '../bloc/notification_preferences_cubit.dart';

extension _Strings on SeenStrings {
  String _t(String ar, String en) => isArabic ? ar : en;

  String get title => _t('تفضيلات الإشعارات', 'Notification preferences');
  String category(NotificationCategory c) => switch (c) {
        NotificationCategory.statusUpdates => _t('تحديثات حالة الطلب', 'Request status updates'),
        NotificationCategory.documents => _t('مستند مطلوب ومهلة', 'Documents and deadlines'),
        NotificationCategory.wallet => _t('المحفظة والشحن', 'Wallet and top-ups'),
        NotificationCategory.subAgents => _t('طلبات الوكلاء الفرعيين', 'Sub-agent requests'),
        NotificationCategory.support => _t('ردود الدعم', 'Support replies'),
        NotificationCategory.promotions => _t('العروض والأخبار', 'Offers and news'),
      };
  String get quietHours => _t('ساعات الهدوء', 'Quiet hours');
  String get urgentOnly => _t('الإشعارات العاجلة فقط', 'Urgent notifications only');
  String quietRange(int from, int to) => _t('من ${_time(from)} إلى ${_time(to)}', 'From ${_time(from)} to ${_time(to)}');
  String _time(int minutes) => clock12(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));
  String get quietFrom => _t('من', 'From');
  String get quietTo => _t('إلى', 'To');
  String get saveRefused => _t('تعذّر حفظ التغيير. عاد المفتاح كما كان.', 'Could not save the change. The switch went back.');
  String get prefsLoadFailed => _t('تعذّر تحميل التفضيلات.', 'Could not load the preferences.');
  String get deviceNotificationsOff =>
      _t('إشعارات الجهاز غير مفعّلة، فلن تصلك التنبيهات.', 'Device notifications are off, so you will not receive alerts.');
  String get turnOn => _t('تفعيل', 'Turn on');
}

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key, this.createCubit, this.permission, this.permissions});

  /// Test seams: the cubit, the device permission and the role (default to DI and the session).
  final NotificationPreferencesCubit Function()? createCubit;
  final PushPermissionService? permission;
  final RolePermissions? permissions;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const NotificationPreferencesScreen());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createCubit ?? InjectionContainer.instance.createNotificationPreferencesCubit)()..load(),
      child: _View(permission: permission, permissions: permissions ?? permissionsOf(context)),
    );
  }
}

class _View extends StatefulWidget {
  const _View({this.permission, required this.permissions});

  final PushPermissionService? permission;
  final RolePermissions permissions;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  PushPermissionStatus? _device;

  PushPermissionService get _service => widget.permission ?? InjectionContainer.instance.pushPermissionService;

  @override
  void initState() {
    super.initState();
    _refreshDevice();
  }

  Future<void> _refreshDevice() async {
    final status = await _service.status();
    if (mounted) {
      setState(() => _device = status);
    }
  }

  Future<void> _editRange(BuildContext context, QuietHours q) async {
    final cubit = context.read<NotificationPreferencesCubit>();
    final s = SeenStrings.of(context);
    TimeOfDay of(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);
    final start = await showTimePicker(context: context, initialTime: of(q.startMinutes), helpText: s.quietFrom);
    if (start == null || !context.mounted) {
      return;
    }
    final end = await showTimePicker(context: context, initialTime: of(q.endMinutes), helpText: s.quietTo);
    if (end == null) {
      return;
    }
    cubit.setQuietRange(start.hour * 60 + start.minute, end.hour * 60 + end.minute);
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final off = _device == PushPermissionStatus.denied || _device == PushPermissionStatus.notDetermined;
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: BlocConsumer<NotificationPreferencesCubit, NotificationPreferencesState>(
            listenWhen: (p, n) => n.saveFailures != p.saveFailures,
            listener: (context, state) => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(s.saveRefused))),
            builder: (context, state) {
              final cubit = context.read<NotificationPreferencesCubit>();
              final prefs = state.preferences;
              final categories = [
                for (final cat in NotificationCategory.values)
                  if (!(cat == NotificationCategory.wallet && !widget.permissions.can(Capability.wallet)) &&
                      !(cat == NotificationCategory.subAgents && !widget.permissions.can(Capability.subAgents)))
                    cat,
              ];
              return Column(
                children: [
                  SeenScreenHeader(title: s.title),
                  Expanded(
                    child: switch (state.status) {
                      PreferencesStatus.loading => Semantics(
                          label: s.loadingLabel,
                          child: const ExcludeSemantics(child: SeenCardsSkeleton(count: 2)),
                        ),
                      PreferencesStatus.failure => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(s.prefsLoadFailed),
                              const SizedBox(height: SeenSpace.s3),
                              SeenButton(label: s.retryAction, onPressed: cubit.load),
                            ],
                          ),
                        ),
                      PreferencesStatus.loaded => ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, SeenSpace.s6),
                          children: [
                            if (off) ...[
                              SeenInlineBanner(
                                tone: SeenBannerTone.info,
                                message: s.deviceNotificationsOff,
                                actionLabel: s.turnOn,
                                onAction: () async {
                                  await Navigator.of(context).push(PushPermissionScreen.route());
                                  await _refreshDevice();
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            _Card(
                              child: Column(
                                children: [
                                  for (var i = 0; i < categories.length; i++)
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: i == categories.length - 1 ? null : Border(bottom: BorderSide(color: c.border)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        child: Row(
                                          children: [
                                            Expanded(child: Text(s.category(categories[i]), style: t.body)),
                                            SeenSwitch(
                                              value: prefs.isOn(categories[i]),
                                              semanticLabel: s.category(categories[i]),
                                              onChanged: (v) => cubit.toggle(categories[i], v),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(s.quietHours, style: t.title)),
                                        SeenSwitch(
                                          value: prefs.quietHours.enabled,
                                          semanticLabel: s.quietHours,
                                          onChanged: cubit.setQuietEnabled,
                                        ),
                                      ],
                                    ),
                                    InkWell(
                                      onTap: prefs.quietHours.enabled ? () => _editRange(context, prefs.quietHours) : null,
                                      borderRadius: const BorderRadius.all(SeenRadius.xs),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Opacity(
                                          opacity: prefs.quietHours.enabled ? 1 : .5,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  s.quietRange(prefs.quietHours.startMinutes, prefs.quietHours.endMinutes),
                                                  style: t.body.copyWith(color: c.inkSecondary),
                                                ),
                                              ),
                                              Text(s.urgentOnly, style: t.caption.copyWith(color: c.inkMuted)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: child,
    );
  }
}
