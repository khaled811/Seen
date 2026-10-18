// NOTIF-04 notification preferences. Arabic / RTL.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/widgets/components.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/domain/entities/role_permissions.dart';
import 'package:seen_booking/features/support/domain/entities/notification_preferences.dart';
import 'package:seen_booking/features/support/domain/repositories/notification_preferences_repository.dart';
import 'package:seen_booking/features/support/presentation/bloc/notification_preferences_cubit.dart';
import 'package:seen_booking/features/support/presentation/screens/notification_preferences_screen.dart';
import 'package:seen_booking/features/system_status/domain/services/push_permission_service.dart';

class _Repo implements NotificationPreferencesRepository {
  NotificationPreferences stored = NotificationPreferences.defaults;
  Failure? saveFailure;
  Failure? getFailure;
  final saved = <NotificationPreferences>[];
  Completer<void>? gate;

  @override
  Future<Either<Failure, NotificationPreferences>> get() async =>
      getFailure == null ? Right(stored) : Left(getFailure!);

  @override
  Future<Either<Failure, NotificationPreferences>> save(NotificationPreferences p) async {
    saved.add(p);
    if (gate != null) {
      await gate!.future;
    }
    if (saveFailure != null) {
      return Left(saveFailure!);
    }
    stored = p;
    return Right(p);
  }
}

class _Device implements PushPermissionService {
  _Device(this.status_);
  final PushPermissionStatus status_;
  @override
  Future<PushPermissionStatus> status() async => status_;
  @override
  Future<PushPermissionStatus> request() async => status_;
  @override
  Future<bool> openSettings() async => true;
  @override
  Future<bool> promptShown() async => true;
  @override
  Future<void> markPromptShown() async {}
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: home,
    );

void main() {
  group('NotificationPreferencesCubit', () {
    test('a switch moves at once and is saved', () async {
      final repo = _Repo();
      final cubit = NotificationPreferencesCubit(repo);
      await cubit.load();
      cubit.toggle(NotificationCategory.promotions, true);
      expect(cubit.state.preferences.isOn(NotificationCategory.promotions), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(repo.stored.isOn(NotificationCategory.promotions), isTrue);
      await cubit.close();
    });

    test('a refused save puts the switch back and counts a failure', () async {
      final repo = _Repo()..saveFailure = const NetworkFailure('off');
      final cubit = NotificationPreferencesCubit(repo);
      await cubit.load();
      cubit.toggle(NotificationCategory.wallet, false);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.preferences.isOn(NotificationCategory.wallet), isTrue);
      expect(cubit.state.saveFailures, 1);
      await cubit.close();
    });

    test('fast changes are sent one request at a time, ending with the latest state', () async {
      final repo = _Repo()..gate = Completer<void>();
      final cubit = NotificationPreferencesCubit(repo);
      await cubit.load();
      cubit.toggle(NotificationCategory.support, false);
      cubit.toggle(NotificationCategory.wallet, false);
      cubit.setQuietEnabled(false);
      await Future<void>.delayed(Duration.zero);
      expect(repo.saved, hasLength(1)); // the first is in flight; the rest wait
      repo.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repo.saved.length, 2);
      final last = repo.stored;
      expect(last.isOn(NotificationCategory.support), isFalse);
      expect(last.isOn(NotificationCategory.wallet), isFalse);
      expect(last.quietHours.enabled, isFalse);
      expect(cubit.state.saveFailures, 0);
      await cubit.close();
    });

    test('the quiet range is saved as minutes after midnight', () async {
      final repo = _Repo();
      final cubit = NotificationPreferencesCubit(repo);
      await cubit.load();
      cubit.setQuietRange(22 * 60 + 30, 6 * 60);
      await Future<void>.delayed(Duration.zero);
      expect(repo.stored.quietHours.startMinutes, 1350);
      expect(repo.stored.quietHours.endMinutes, 360);
      await cubit.close();
    });

    test('a load failure can be retried', () async {
      final repo = _Repo()..getFailure = const NetworkFailure('off');
      final cubit = NotificationPreferencesCubit(repo);
      await cubit.load();
      expect(cubit.state.status, PreferencesStatus.failure);
      repo.getFailure = null;
      await cubit.load();
      expect(cubit.state.status, PreferencesStatus.loaded);
      await cubit.close();
    });
  });

  group('screen', () {
    Future<_Repo> open(WidgetTester tester, {RolePermissions perms = RolePermissions.all, PushPermissionStatus device = PushPermissionStatus.granted, _Repo? repo}) async {
      final r = repo ?? _Repo();
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(NotificationPreferencesScreen(
        createCubit: () => NotificationPreferencesCubit(r),
        permission: _Device(device),
        permissions: perms,
      )));
      await tester.pump();
      await tester.pump();
      return r;
    }

    testWidgets('shows the categories as in the design, offers off, quiet hours with their range', (tester) async {
      await open(tester);
      expect(find.text('تفضيلات الإشعارات'), findsOneWidget);
      expect(find.text('تحديثات حالة الطلب'), findsOneWidget);
      expect(find.text('العروض والأخبار'), findsOneWidget);
      expect(find.text('ساعات الهدوء'), findsOneWidget);
      expect(find.textContaining('11:00 م'), findsOneWidget);
      expect(find.text('الإشعارات العاجلة فقط'), findsOneWidget);
      final switches = tester.widgetList<SeenSwitch>(find.byType(SeenSwitch)).map((s) => s.value).toList();
      expect(switches, [true, true, true, true, true, false, true]);
    });

    testWidgets('tapping a switch saves it', (tester) async {
      final repo = await open(tester);
      await tester.tap(find.byType(SeenSwitch).at(5));
      await tester.pump();
      await tester.pump();
      expect(repo.stored.isOn(NotificationCategory.promotions), isTrue);
    });

    testWidgets('a refused save says so and the switch returns', (tester) async {
      final repo = _Repo();
      await open(tester, repo: repo);
      repo.saveFailure = const NetworkFailure('off');
      await tester.tap(find.byType(SeenSwitch).first);
      await tester.pump();
      await tester.pump();
      expect(find.text('تعذّر حفظ التغيير. عاد المفتاح كما كان.'), findsOneWidget);
      expect(tester.widget<SeenSwitch>(find.byType(SeenSwitch).first).value, isTrue);
    });

    testWidgets('staff do not see wallet or sub-agent categories', (tester) async {
      await open(tester, perms: const RolePermissions(AgentPosition.staff));
      expect(find.text('المحفظة والشحن'), findsNothing);
      expect(find.text('طلبات الوكلاء الفرعيين'), findsNothing);
      expect(find.text('ردود الدعم'), findsOneWidget);
    });

    testWidgets('device notifications off shows a banner with a way to turn them on', (tester) async {
      await open(tester, device: PushPermissionStatus.denied);
      expect(find.textContaining('إشعارات الجهاز غير مفعّلة'), findsOneWidget);
      expect(find.text('تفعيل'), findsOneWidget);
    });

    testWidgets('quiet hours off dims the range and stops editing', (tester) async {
      final repo = await open(tester);
      await tester.tap(find.byType(SeenSwitch).last);
      await tester.pump();
      await tester.pump();
      expect(repo.stored.quietHours.enabled, isFalse);
      await tester.tap(find.textContaining('11:00 م'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
    });

    testWidgets('a load failure offers retry', (tester) async {
      final repo = _Repo()..getFailure = const NetworkFailure('off');
      await open(tester, repo: repo);
      expect(find.text('تعذّر تحميل التفضيلات.'), findsOneWidget);
      repo.getFailure = null;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();
      await tester.pump();
      expect(find.text('تحديثات حالة الطلب'), findsOneWidget);
    });
  });
}
