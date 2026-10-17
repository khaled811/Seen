// SYS-03 / 04 / 05: version rules, the status cubit, the gate screens, the
// no-permission view and the access request. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/foundation/seen_icons.dart';
import 'package:seen_booking/core/presentation/widgets/system_state.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/system_status/data/models/app_status_dto.dart';
import 'package:seen_booking/features/system_status/domain/entities/app_status.dart';
import 'package:seen_booking/features/system_status/domain/entities/app_version.dart';
import 'package:seen_booking/features/system_status/domain/repositories/access_request_repository.dart';
import 'package:seen_booking/features/system_status/domain/repositories/app_status_repository.dart';
import 'package:seen_booking/features/system_status/domain/services/store_launcher.dart';
import 'package:seen_booking/features/system_status/domain/usecases/system_status_usecases.dart';
import 'package:seen_booking/features/system_status/presentation/bloc/access_request_cubit.dart';
import 'package:seen_booking/features/system_status/presentation/bloc/app_status_cubit.dart';
import 'package:seen_booking/features/system_status/presentation/widgets/app_status_gate.dart';

class _FakeStatusRepo implements AppStatusRepository {
  Either<Failure, AppStatus> result = const Right(AppStatus.ok);
  int calls = 0;

  @override
  Future<Either<Failure, AppStatus>> fetch() async {
    calls++;
    return result;
  }
}

class _FakeAccessRepo implements AccessRequestRepository {
  Either<Failure, void> result = const Right(null);
  final areas = <String>[];

  @override
  Future<Either<Failure, void>> request(String area) async {
    areas.add(area);
    return result;
  }
}

class _FakeStore implements StoreLauncher {
  final opened = <String>[];
  bool ok = true;

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return ok;
  }
}

AppStatusCubit _cubit(_FakeStatusRepo repo, {String version = '2.0.0', DateTime Function()? now}) => AppStatusCubit(
      getStatus: GetAppStatusUseCase(repo),
      currentVersion: () async => version,
      now: now,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: child,
    ),
  );
  await tester.pump();
}

void main() {
  group('AppVersion', () {
    test('compares numerically and ignores build suffixes', () {
      expect(AppVersion.tryParse('2.10')! > AppVersion.tryParse('2.9')!, isTrue);
      expect(AppVersion.tryParse('2.5.0+14')!.compareTo(AppVersion.tryParse('2.5')!), 0);
      expect(AppVersion.tryParse('1.9.9')! < AppVersion.tryParse('2.0.0')!, isTrue);
      expect(AppVersion.tryParse('abc'), isNull);
      expect(AppVersion.tryParse(null), isNull);
      expect(AppVersion.tryParse(''), isNull);
    });
  });

  group('AppStatusDto', () {
    test('reads maintenance, eta and versions; tolerates missing parts', () {
      final dto = AppStatusDto.fromJson({
        'maintenance': {'active': true, 'etaAt': '2026-10-17T02:30:00Z'},
        'minimumVersion': '2.0.0',
        'latestVersion': '2.5.0',
        'storeUrl': 'https://store.example/app',
        'updateNote': 'wallet',
      });
      expect(dto.maintenance, isTrue);
      expect(dto.maintenanceEta, isNotNull);
      expect(dto.toEntity().latestVersion, '2.5.0');
      final empty = AppStatusDto.fromJson(const {});
      expect(empty.maintenance, isFalse);
      expect(empty.maintenanceEta, isNull);
    });
  });

  group('AppStatusCubit', () {
    test('open when nothing to report; fail-open when the call fails', () async {
      final repo = _FakeStatusRepo();
      final cubit = _cubit(repo);
      await cubit.check();
      expect(cubit.state, const AppStatusOpen());
      repo.result = const Left(NetworkFailure('offline'));
      await cubit.check();
      expect(cubit.state, const AppStatusOpen());
      await cubit.close();
    });

    test('maintenance wins over updates; eta is kept', () async {
      final eta = DateTime(2026, 10, 17, 2, 30);
      final repo = _FakeStatusRepo()
        ..result = Right(AppStatus(maintenance: true, maintenanceEta: eta, minimumVersion: '9.0.0'));
      final cubit = _cubit(repo);
      await cubit.check();
      expect(cubit.state, AppStatusMaintenance(eta: eta));
      await cubit.close();
    });

    test('maintenance stays when a retry fails, and ends when the server says so', () async {
      final repo = _FakeStatusRepo()..result = const Right(AppStatus(maintenance: true));
      final cubit = _cubit(repo);
      await cubit.check();
      repo.result = const Left(NetworkFailure('offline'));
      await cubit.check();
      expect(cubit.state, const AppStatusMaintenance());
      repo.result = const Right(AppStatus.ok);
      await cubit.check();
      expect(cubit.state, const AppStatusOpen());
      await cubit.close();
    });

    test('hard update below the minimum; soft update below the latest, postponed per version', () async {
      final repo = _FakeStatusRepo()
        ..result = const Right(AppStatus(minimumVersion: '2.1.0', latestVersion: '2.5.0', storeUrl: 'https://s'));
      final cubit = _cubit(repo);
      await cubit.check();
      expect(cubit.state, const AppStatusUpdateRequired(storeUrl: 'https://s'));

      repo.result = const Right(AppStatus(minimumVersion: '1.0.0', latestVersion: '2.5.0', updateNote: 'n'));
      await cubit.check();
      expect(cubit.state, const AppStatusUpdateAvailable(version: '2.5.0', note: 'n'));
      cubit.postponeUpdate();
      expect(cubit.state, const AppStatusOpen());
      await cubit.check();
      expect(cubit.state, const AppStatusOpen());

      repo.result = const Right(AppStatus(latestVersion: '2.6.0'));
      await cubit.check();
      expect(cubit.state, const AppStatusUpdateAvailable(version: '2.6.0'));
      await cubit.close();
    });

    test('a malformed version never blocks', () async {
      final repo = _FakeStatusRepo()..result = const Right(AppStatus(minimumVersion: 'x.y', latestVersion: '??'));
      final cubit = _cubit(repo);
      await cubit.check();
      expect(cubit.state, const AppStatusOpen());
      await cubit.close();
    });

    test('resume re-checks only when stale, always while blocked', () async {
      var now = DateTime(2026, 10, 17, 9);
      final repo = _FakeStatusRepo();
      final cubit = _cubit(repo, now: () => now);
      await cubit.check();
      expect(repo.calls, 1);
      now = now.add(const Duration(minutes: 1));
      await cubit.checkOnResume();
      expect(repo.calls, 1);
      now = now.add(const Duration(minutes: 10));
      await cubit.checkOnResume();
      expect(repo.calls, 2);

      repo.result = const Right(AppStatus(maintenance: true));
      await cubit.check();
      await cubit.checkOnResume();
      expect(repo.calls, 4);
      await cubit.close();
    });
  });

  group('AppStatusGate', () {
    testWidgets('maintenance covers the app, shows the eta and retries', (tester) async {
      final eta = DateTime.now().add(const Duration(minutes: 30));
      final repo = _FakeStatusRepo()..result = Right(AppStatus(maintenance: true, maintenanceEta: eta));
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.check();
      await _pump(
        tester,
        BlocProvider.value(
          value: cubit,
          child: AppStatusGate(storeLauncher: _FakeStore(), child: const Scaffold(body: Text('الصفحة الرئيسية'))),
        ),
      );
      expect(find.text('نُحسّن سين Business الآن'), findsOneWidget);
      expect(find.textContaining('الوقت المتوقع'), findsOneWidget);
      expect(find.textContaining('طلباتك وبياناتك محفوظة'), findsOneWidget);

      repo.result = const Right(AppStatus.ok);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('نُحسّن سين Business الآن'), findsNothing);
      expect(find.text('الصفحة الرئيسية'), findsOneWidget);
    });

    testWidgets('required update opens the store link', (tester) async {
      final repo = _FakeStatusRepo()..result = const Right(AppStatus(minimumVersion: '9.0.0', storeUrl: 'https://s.example'));
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.check();
      final store = _FakeStore();
      await _pump(
        tester,
        BlocProvider.value(
          value: cubit,
          child: AppStatusGate(storeLauncher: store, child: const Scaffold(body: Text('app'))),
        ),
      );
      expect(find.text('تحديث مطلوب'), findsOneWidget);
      await tester.tap(find.text('تحديث من المتجر'));
      await tester.pump();
      expect(store.opened, ['https://s.example']);
    });

    testWidgets('required update without a link: the button is disabled', (tester) async {
      final repo = _FakeStatusRepo()..result = const Right(AppStatus(minimumVersion: '9.0.0'));
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.check();
      final store = _FakeStore();
      await _pump(
        tester,
        BlocProvider.value(
          value: cubit,
          child: AppStatusGate(storeLauncher: store, child: const Scaffold(body: Text('app'))),
        ),
      );
      await tester.tap(find.text('تحديث من المتجر'), warnIfMissed: false);
      await tester.pump();
      expect(store.opened, isEmpty);
    });

    testWidgets('optional update floats over the app; "later" dismisses; store failure says so', (tester) async {
      final repo = _FakeStatusRepo()
        ..result = const Right(AppStatus(latestVersion: '9.1.0', storeUrl: 'https://s.example', updateNote: 'تحسينات المحفظة'));
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.check();
      final store = _FakeStore()..ok = false;
      await _pump(
        tester,
        BlocProvider.value(
          value: cubit,
          child: AppStatusGate(storeLauncher: store, child: const Scaffold(body: Text('app'))),
        ),
      );
      expect(find.text('app'), findsOneWidget);
      expect(find.text('تحديث اختياري متاح'), findsOneWidget);
      expect(find.textContaining('تحسينات المحفظة'), findsOneWidget);

      await tester.tap(find.text('تحديث'));
      await tester.pump();
      await tester.pump();
      expect(find.text('تعذّر فتح المتجر.'), findsOneWidget);

      await tester.tap(find.text('لاحقًا'));
      await tester.pump();
      expect(find.text('تحديث اختياري متاح'), findsNothing);
    });
  });

  group('SeenForbiddenView + AccessRequestCubit', () {
    test('sends once per refusal; failure can be retried', () async {
      final repo = _FakeAccessRepo()..result = const Left(NetworkFailure('offline'));
      final cubit = AccessRequestCubit(RequestAccessUseCase(repo), area: 'wallet');
      await cubit.send();
      expect(cubit.state.status, AccessRequestStatus.failed);
      repo.result = const Right(null);
      await cubit.send();
      expect(cubit.state.status, AccessRequestStatus.sent);
      await cubit.send();
      expect(repo.areas, ['wallet', 'wallet']);
      await cubit.close();
    });

    testWidgets('shows the explanation, the rule, and wires both buttons', (tester) async {
      var requested = 0;
      var home = 0;
      await _pump(
        tester,
        Scaffold(
          body: SeenForbiddenView(
            icon: SeenIcons.gear,
            title: 'ليس لديك صلاحية',
            message: 'اطلب الصلاحية من مالك الحساب.',
            requestLabel: 'طلب الصلاحية',
            onRequest: () => requested++,
            backLabel: 'العودة للرئيسية',
            onBack: () => home++,
            rule: 'قاعدة: نخفي الأقسام',
          ),
        ),
      );
      expect(find.text('ليس لديك صلاحية'), findsOneWidget);
      expect(find.textContaining('قاعدة'), findsOneWidget);
      await tester.tap(find.text('طلب الصلاحية'));
      await tester.tap(find.text('العودة للرئيسية'));
      expect(requested, 1);
      expect(home, 1);
    });

    testWidgets('once requested the button is disabled', (tester) async {
      var requested = 0;
      await _pump(
        tester,
        Scaffold(
          body: SeenForbiddenView(
            icon: SeenIcons.gear,
            title: 't',
            message: 'm',
            requestLabel: 'طلب الصلاحية',
            onRequest: () => requested++,
            requested: true,
            backLabel: 'back',
            onBack: null,
          ),
        ),
      );
      await tester.tap(find.text('طلب الصلاحية'), warnIfMissed: false);
      expect(requested, 0);
    });
  });
}
