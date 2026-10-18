// BOOK-09 service coming soon. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/services/domain/repositories/service_interest_repository.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_interest_cubit.dart';
import 'package:seen_booking/features/services/presentation/widgets/coming_soon_sheet.dart';

class _Repo implements ServiceInterestRepository {
  Failure? failure;
  final keys = <String>[];

  @override
  Future<Either<Failure, void>> notifyWhenAvailable(String serviceKey) async {
    keys.add(serviceKey);
    return failure == null ? const Right(null) : Left(failure!);
  }

  @override
  bool alreadyRequested(String serviceKey) => keys.contains(serviceKey);
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
      home: Scaffold(body: home),
    );

void main() {
  group('ServiceInterestCubit', () {
    test('registers once; a repeat is ignored; a failure can be retried', () async {
      final repo = _Repo()..failure = const NetworkFailure('off');
      final cubit = ServiceInterestCubit(repo, serviceKey: 'hotels');
      await cubit.notify();
      expect(cubit.state.status, InterestStatus.failed);
      repo.failure = null;
      await cubit.notify();
      expect(cubit.state.status, InterestStatus.registered);
      await cubit.notify();
      expect(repo.keys, ['hotels', 'hotels']);
      await cubit.close();
    });

    test('opens as registered when it was asked before', () async {
      final repo = _Repo()..keys.add('hotels');
      final cubit = ServiceInterestCubit(repo, serviceKey: 'hotels');
      expect(cubit.state.status, InterestStatus.registered);
      await cubit.close();
    });
  });

  group('coming-soon sheet', () {
    Future<_Repo> open(WidgetTester tester, {_Repo? repo}) async {
      final r = repo ?? _Repo();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () => showServiceComingSoonSheet(
            context,
            serviceKey: 'hotels',
            name: 'حجز الفنادق',
            icon: Icons.hotel,
            createCubit: () => ServiceInterestCubit(r, serviceKey: 'hotels'),
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return r;
    }

    testWidgets('shows the service name and body; "notify me" registers and says so', (tester) async {
      final repo = await open(tester);
      expect(find.text('حجز الفنادق قريبًا'), findsOneWidget);
      expect(find.textContaining('نعمل على إضافة حجز الفنادق'), findsOneWidget);
      await tester.tap(find.text('نبّهني عند الإطلاق'));
      await tester.pump();
      await tester.pump();
      expect(repo.keys, ['hotels']);
      expect(find.text('تم تسجيل اهتمامك. سنبلغك عند الإطلاق.'), findsOneWidget);
    });

    testWidgets('a failure shows a message and the button stays usable', (tester) async {
      final repo = await open(tester, repo: _Repo()..failure = const NetworkFailure('off'));
      await tester.tap(find.text('نبّهني عند الإطلاق'));
      await tester.pump();
      await tester.pump();
      expect(find.text('تعذّر تسجيل التنبيه. حاول مرة أخرى.'), findsOneWidget);
      repo.failure = null;
      await tester.tap(find.text('نبّهني عند الإطلاق'));
      await tester.pump();
      await tester.pump();
      expect(find.text('تم تسجيل اهتمامك. سنبلغك عند الإطلاق.'), findsOneWidget);
    });

    testWidgets('Close dismisses the sheet', (tester) async {
      await open(tester);
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();
      expect(find.text('حجز الفنادق قريبًا'), findsNothing);
    });
  });
}
