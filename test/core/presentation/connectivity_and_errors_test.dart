// Connectivity banner (Figma SYS-01) and network / server error patterns
// (SYS-02 / 02b). Arabic / RTL.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/network/connectivity_monitor.dart';
import 'package:seen_booking/core/network/data_freshness.dart';
import 'package:seen_booking/core/presentation/connectivity/connectivity_cubit.dart';
import 'package:seen_booking/core/presentation/connectivity/connectivity_shell.dart';
import 'package:seen_booking/core/presentation/widgets/error_patterns.dart';
import 'package:seen_booking/core/theme/app_theme.dart';

class _FakeMonitor implements ConnectivityMonitor {
  _FakeMonitor({this.online = true});

  bool online;
  final controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => controller.stream;
}

Widget _app(Widget home, {ConnectivityCubit? cubit}) {
  final app = MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.light,
    builder: cubit == null ? null : (context, child) => SeenConnectivityShell(child: child),
    home: Scaffold(body: home),
  );
  return cubit == null ? app : BlocProvider.value(value: cubit, child: app);
}

Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pump();
}

void main() {
  group('Failure.reference', () {
    test('status and short request id', () {
      expect(
        const ServerFailure('x', statusCode: 502, details: {'requestId': 'a91f33c2'}).reference,
        '502 · a91f',
      );
      expect(const ServerFailure('x', code: 'BOOM').reference, 'BOOM');
      expect(const ServerFailure('x').reference, isNull);
      expect(const NetworkFailure('x').reference, isNull);
    });
  });

  group('ConnectivityCubit', () {
    test('offline → restored → back to online by itself, remembering the last sync time', () async {
      final monitor = _FakeMonitor();
      final freshness = DataFreshness()..markFresh(DateTime(2026, 10, 15, 10, 42));
      final cubit = ConnectivityCubit(
        monitor: monitor,
        freshness: freshness,
        restoredFor: const Duration(milliseconds: 30),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.status, ConnectivityStatus.online);

      monitor.controller.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.status, ConnectivityStatus.offline);
      expect(cubit.state.lastSyncedAt, DateTime(2026, 10, 15, 10, 42));

      monitor.controller.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.status, ConnectivityStatus.restored);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(cubit.state.status, ConnectivityStatus.online);
    });

    test('recheck asks the platform again', () async {
      final monitor = _FakeMonitor(online: false);
      final cubit = ConnectivityCubit(monitor: monitor, freshness: DataFreshness());
      addTearDown(cubit.close);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(cubit.state.status, ConnectivityStatus.offline);
      monitor.online = true;
      await cubit.recheck();
      expect(cubit.state.status, ConnectivityStatus.restored);
    });
  });

  group('SeenConnectivityShell', () {
    testWidgets('offline shows the banner with the last update time and Retry', (tester) async {
      final monitor = _FakeMonitor(online: false);
      final cubit = ConnectivityCubit(
        monitor: monitor,
        freshness: DataFreshness()..markFresh(DateTime(2026, 10, 15, 10, 42)),
      );
      addTearDown(() => cubit.close().ignore());
      await tester.pumpWidget(_app(const Text('BODY'), cubit: cubit));
      await tick(tester);
      expect(find.text('أنت غير متصل. تعرض البيانات آخر تحديث 10:42.'), findsOneWidget);
      expect(find.text('BODY'), findsOneWidget);

      monitor.online = true;
      await tester.tap(find.text('إعادة'));
      await tick(tester);
      expect(find.text('عاد الاتصال.'), findsOneWidget);
      await cubit.close(); // cancels the auto-hide timer
    });

    testWidgets('online shows nothing extra', (tester) async {
      final cubit = ConnectivityCubit(monitor: _FakeMonitor(), freshness: DataFreshness());
      addTearDown(() => cubit.close().ignore());
      await tester.pumpWidget(_app(const Text('BODY'), cubit: cubit));
      await tick(tester);
      expect(find.text('عاد الاتصال.'), findsNothing);
      expect(find.textContaining('غير متصل'), findsNothing);
    });
  });

  group('error patterns', () {
    testWidgets('inline error retries', (tester) async {
      var retried = 0;
      await tester.pumpWidget(_app(SeenInlineError(
        title: 'تعذّر تحميل سجل العمليات',
        retryLabel: 'إعادة المحاولة',
        onRetry: () => retried++,
      )));
      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, 1);
    });

    testWidgets('the slow-load notice appears only after the delay, and only while loading', (tester) async {
      Widget build(bool loading) => _app(SeenSlowLoadNotice(
            loading: loading,
            after: const Duration(seconds: 8),
            message: 'الخادم يستغرق وقتًا أطول من المعتاد. ما زلنا نحاول…',
            cancelLabel: 'إلغاء',
            onCancel: () {},
          ));
      await tester.pumpWidget(build(true));
      expect(find.textContaining('يستغرق وقتًا'), findsNothing);
      await tester.pump(const Duration(seconds: 9));
      expect(find.textContaining('يستغرق وقتًا'), findsOneWidget);
      await tester.pumpWidget(build(false));
      expect(find.textContaining('يستغرق وقتًا'), findsNothing);
    });

    testWidgets('the error sheet resolves true on retry and false on cancel', (tester) async {
      bool? result;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showSeenErrorSheet(
            context,
            title: 'لم يكتمل الشحن',
            detail: 'رمز الخطأ 502 · a91f',
            retryLabel: 'حاول مجددًا',
            cancelLabel: 'إلغاء',
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('لم يكتمل الشحن'), findsOneWidget);
      expect(find.text('رمز الخطأ 502 · a91f'), findsOneWidget);
      await tester.tap(find.text('حاول مجددًا'));
      await tester.pumpAndSettle();
      expect(result, isTrue);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('the full-screen error shows the copy, retry and support', (tester) async {
      var retried = 0;
      var support = 0;
      await tester.pumpWidget(_app(SeenFullScreenError(
        title: 'حدث خطأ غير متوقع',
        body: 'نعمل على إصلاحه الآن. رمز الخطأ 500 · 7c2e',
        retryLabel: 'إعادة المحاولة',
        onRetry: () => retried++,
        supportLabel: 'تواصل مع الدعم',
        onSupport: () => support++,
      )));
      expect(find.text('حدث خطأ غير متوقع'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.tap(find.text('تواصل مع الدعم'));
      expect((retried, support), (1, 1));
    });
  });
}
