// BOOK-10 hospital quota and availability. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/services/domain/entities/hospital.dart';
import 'package:seen_booking/features/services/domain/repositories/hospital_repository.dart';
import 'package:seen_booking/features/services/presentation/bloc/hospital_picker_cubit.dart';
import 'package:seen_booking/features/services/presentation/widgets/hospital_picker_sheet.dart';

class _Repo implements HospitalRepository {
  List<Hospital> list = const [
    Hospital(id: 'h1', name: 'مستشفى الأردن', capacity: 40, remaining: 12),
    Hospital(id: 'h2', name: 'المستشفى التخصصي', capacity: 30, remaining: 3),
    Hospital(id: 'h3', name: 'مستشفى الخالدي', capacity: 25, remaining: 0),
  ];
  Failure? failure;

  @override
  Future<Either<Failure, List<Hospital>>> availability(String serviceId) async =>
      failure == null ? Right(list) : Left(failure!);
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
  group('Hospital', () {
    test('full, low and used share', () {
      const full = Hospital(id: 'a', name: 'a', capacity: 25, remaining: 0);
      const low = Hospital(id: 'b', name: 'b', capacity: 30, remaining: 3);
      const ok = Hospital(id: 'c', name: 'c', capacity: 40, remaining: 12);
      expect(full.isFull, isTrue);
      expect(low.isLow, isTrue);
      expect(ok.isLow, isFalse);
      expect(ok.usedFraction, closeTo(0.7, 1e-9));
      expect(full.usedFraction, 1);
      expect(const Hospital(id: 'z', name: 'z', capacity: 0, remaining: 0).usedFraction, 1);
    });
  });

  group('HospitalPickerCubit', () {
    test('pre-selects the first hospital with places; a full one cannot be chosen', () async {
      final cubit = HospitalPickerCubit(_Repo(), serviceId: 's');
      await cubit.load();
      expect(cubit.state.selectedId, 'h1');
      cubit.select('h3');
      expect(cubit.state.selectedId, 'h1');
      cubit.select('h2');
      expect(cubit.state.selectedId, 'h2');
      await cubit.close();
    });

    test('everything full: nothing is selected', () async {
      final repo = _Repo()..list = const [Hospital(id: 'h3', name: 'x', capacity: 25, remaining: 0)];
      final cubit = HospitalPickerCubit(repo, serviceId: 's');
      await cubit.load();
      expect(cubit.state.allFull, isTrue);
      expect(cubit.state.selected, isNull);
      await cubit.close();
    });

    test('a failure can be retried', () async {
      final repo = _Repo()..failure = const NetworkFailure('off');
      final cubit = HospitalPickerCubit(repo, serviceId: 's');
      await cubit.load();
      expect(cubit.state.status, HospitalsStatus.failure);
      repo.failure = null;
      await cubit.load();
      expect(cubit.state.status, HospitalsStatus.loaded);
      await cubit.close();
    });
  });

  group('sheet', () {
    Future<void> open(WidgetTester tester, _Repo repo, void Function(HospitalChoice?) onResult) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => onResult(await showHospitalPickerSheet(
            context,
            serviceId: 's',
            createCubit: () => HospitalPickerCubit(repo, serviceId: 's'),
          )),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows each hospital with its places, dims the full one, and continues with the selected', (tester) async {
      HospitalChoice? chosen;
      await open(tester, _Repo(), (c) => chosen = c);
      expect(find.text('اختر المستشفى'), findsOneWidget);
      expect(find.text('السعة المتبقية هذا الأسبوع'), findsOneWidget);
      expect(find.text('١٢ مقعد متبقٍ'), findsOneWidget);
      expect(find.text('٣ مقعد متبقٍ'), findsOneWidget);
      expect(find.text('مكتمل'), findsOneWidget);
      await tester.tap(find.text('مستشفى الخالدي'), warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.text('المستشفى التخصصي'));
      await tester.pump();
      await tester.tap(find.text('متابعة إلى التأشيرة'));
      await tester.pumpAndSettle();
      expect(chosen, const HospitalChoice(id: 'h2', name: 'المستشفى التخصصي'));
    });

    testWidgets('all hospitals full: a message and Continue stays off', (tester) async {
      HospitalChoice? chosen;
      final repo = _Repo()..list = const [Hospital(id: 'h3', name: 'مستشفى الخالدي', capacity: 25, remaining: 0)];
      await open(tester, repo, (c) => chosen = c);
      expect(find.textContaining('كل المستشفيات مكتملة'), findsOneWidget);
      await tester.tap(find.text('متابعة إلى التأشيرة'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      expect(find.text('اختر المستشفى'), findsOneWidget);
    });

    testWidgets('a load failure offers retry', (tester) async {
      final repo = _Repo()..failure = const NetworkFailure('off');
      await open(tester, repo, (_) {});
      expect(find.text('تعذّر تحميل المستشفيات.'), findsOneWidget);
      repo.failure = null;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('مستشفى الأردن'), findsOneWidget);
    });
  });
}
