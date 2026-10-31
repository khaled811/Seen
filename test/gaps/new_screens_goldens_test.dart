// One RTL frame per new screen of the GAPS work (design/gaps SPEC §14), 390 wide. These are new
// baselines (there is no earlier version): a later change to any of these screens shows up here and
// is reviewed before the baseline is regenerated with `--update-goldens`.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/presentation/bloc/email_change_cubit.dart';
import 'package:seen_booking/features/auth/presentation/bloc/two_factor_cubits.dart';
import 'package:seen_booking/features/auth/presentation/screens/change_email_screen.dart';
import 'package:seen_booking/features/auth/presentation/screens/two_factor_setup_screen.dart';
import 'package:seen_booking/features/profile/domain/entities/avatar.dart';
import 'package:seen_booking/features/profile/presentation/screens/avatar_crop_screen.dart';
import 'package:seen_booking/features/reports/domain/entities/report.dart';
import 'package:seen_booking/features/reports/presentation/bloc/report_cubits.dart';
import 'package:seen_booking/features/reports/presentation/screens/report_result_screen.dart';
import 'package:seen_booking/features/requests/presentation/widgets/sensitive_values.dart';
import 'package:seen_booking/features/services/presentation/bloc/passport_scan_cubit.dart';
import 'package:seen_booking/features/services/presentation/screens/passport_scan_screen.dart';
import 'package:seen_booking/features/support/presentation/bloc/ticket_categories_cubit.dart';
import 'package:seen_booking/features/support/presentation/bloc/ticket_rating_cubit.dart';
import 'package:seen_booking/features/support/presentation/widgets/ticket_category_sheet.dart';
import 'package:seen_booking/features/support/presentation/widgets/ticket_rating_card.dart';
import 'package:seen_booking/features/reports/domain/repositories/reports_repository.dart';
import 'package:seen_booking/core/error/failure.dart';

import '../support/email_change_fakes.dart';
import '../support/passport_fakes.dart';
import '../support/rating_fakes.dart';
import '../support/sensitive_values_fakes.dart';
import '../support/two_factor_fakes.dart';

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
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

Future<void> _shot(WidgetTester tester, String name, Widget screen, {double height = 844, Future<void> Function()? after}) async {
  await tester.binding.setSurfaceSize(Size(390, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(screen));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  if (after != null) {
    await after();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }
  await screenMatchesGolden(tester, name);
}

class _Reports implements ReportsRepository {
  @override
  Future<Either<Failure, ReportData>> run(ReportRequest request) async => const Right(ReportData(
        columns: [
          ReportColumnInfo(key: 'ref', label: 'رقم الطلب', kind: ReportColumnKind.text),
          ReportColumnInfo(key: 'traveler', label: 'المسافر', kind: ReportColumnKind.text),
          ReportColumnInfo(key: 'service', label: 'الخدمة', kind: ReportColumnKind.text),
          ReportColumnInfo(key: 'status', label: 'الحالة', kind: ReportColumnKind.text),
          ReportColumnInfo(key: 'amount', label: 'المبلغ', kind: ReportColumnKind.money),
        ],
        rows: [
          ['SB-1001', 'أمل صالح', 'تأشيرة السعودية', 'مكتمل', '85.00'],
          ['SB-1002', 'خالد علي', 'موافقة أمنية', 'قيد المراجعة', '170.00'],
          ['SB-1003', 'هدى محمد', 'تأشيرة السعودية', 'مكتمل', '85.00'],
        ],
        totals: ['', '', '', '', '340.00'],
        totalRows: 3,
        truncated: false,
      ));

  @override
  Future<Either<Failure, ReportFile>> export(ReportRequest request, ReportFormat format) => throw UnimplementedError();
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    await loadAppFonts();
    InjectionContainer.instance.init();
  });

  // ── SEC ──
  testGoldens(
    'SEC-02 scan',
    (t) => _shot(t, 'sec_02_scan', TwoFactorSetupScreen(mode: TwoFactorFlowMode.enable, createCubit: () => TwoFactorFlowCubit(FakeTwoFactorRepository(), mode: TwoFactorFlowMode.enable)..start())),
  );
  testGoldens(
    'SEC-03 code',
    (t) => _shot(t, 'sec_03_code', TwoFactorSetupScreen(mode: TwoFactorFlowMode.regenerate, createCubit: () => TwoFactorFlowCubit(FakeTwoFactorRepository(), mode: TwoFactorFlowMode.regenerate))),
  );
  testGoldens(
    'SEC-04 recovery codes',
    (t) => _shot(
      t,
      'sec_04_codes',
      TwoFactorSetupScreen(mode: TwoFactorFlowMode.regenerate, createCubit: () => TwoFactorFlowCubit(FakeTwoFactorRepository(), mode: TwoFactorFlowMode.regenerate)),
      after: () async {
        await t.enterText(find.byType(TextField).first, '123456');
        await t.pump();
      },
    ),
  );

  // ── ACC ──
  testGoldens(
    'ACC-09 form',
    (t) => _shot(t, 'acc_09_form', ChangeEmailScreen(createCubit: () => EmailChangeCubit(FakeEmailChangeRepository())..load())),
  );
  testGoldens(
    'ACC-10 check your email',
    (t) => _shot(
      t,
      'acc_10_sent',
      ChangeEmailScreen(createCubit: () => EmailChangeCubit(FakeEmailChangeRepository())..load()),
      after: () async {
        final fields = find.byType(TextField);
        await t.enterText(fields.at(1), 'new@agency.com');
        await t.enterText(fields.at(2), 'Secret@123');
        await t.pump();
        await t.tap(find.text(lookupAppLocalizations(const Locale('ar')).accSend));
        await t.pump();
      },
    ),
  );

  // ── PRIV ──
  testGoldens(
    'PRIV-01 hidden values',
    (t) => _shot(
      t,
      'priv_01_hidden',
      Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SensitiveValuesScope(
              requestId: 'r1',
              repository: FakeSensitiveValuesRepository(),
              introStore: FakeRevealIntroStore(isSeen: true),
              child: const TravelerSensitiveBlock(index: 0),
            ),
          ),
        ),
      ),
      height: 400,
    ),
  );

  // ── PROF ──
  testGoldens('PROF-02 crop', (t) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 800, 600), Paint()..color = const Color(0xFF7B52F5));
    canvas.drawCircle(const Offset(400, 300), 150, Paint()..color = const Color(0xFFFFFFFF));
    final png = await t.runAsync<Uint8List>(() async {
      final image = await recorder.endRecording().toImage(800, 600);
      return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    });
    await _shot(t, 'prof_02_crop', AvatarCropScreen(picked: const PickedAvatar(path: 'p.png', fileName: 'p.png', sizeBytes: 10), loadBytes: (_) async => png!));
  });

  // ── SUP ──
  testGoldens(
    'SUP-06 rating card',
    (t) {
      final cubit = TicketRatingCubit(FakeTicketRatingRepository(), ticketId: '7')..select(4);
      addTearDown(cubit.close);
      return _shot(
        t,
        'sup_06_rating',
        Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: BlocProvider.value(value: cubit, child: const TicketRatingCard())))),
        height: 420,
      );
    },
  );
  testGoldens('SUP-07 category sheet', (t) {
    final cubit = TicketCategoriesCubit(FakeTicketCategoriesRepository());
    addTearDown(cubit.close);
    return _shot(
      t,
      'sup_07_categories',
      Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => showTicketCategorySheet(context, cubit: cubit, selectedCode: 'payments'), child: const Text('open'))))),
      after: () async {
        await t.tap(find.text('open'));
        await t.pump();
      },
    );
  });

  // ── PASS ──
  testGoldens(
    'PASS-02 capture',
    (t) => _shot(
      t,
      'pass_02_capture',
      PassportScanScreen(
        fields: const {'passportNumber': 'رقم الجواز', 'fullName': 'الاسم الكامل'},
        createCubit: (keys) => PassportScanCubit(reader: FakePassportReader(), picker: FakePassportPicker(), fieldKeys: keys),
      ),
    ),
  );
  testGoldens(
    'PASS-03 review',
    (t) => _shot(
      t,
      'pass_03_review',
      PassportScanScreen(
        fields: const {'passportNumber': 'رقم الجواز', 'fullName': 'الاسم الكامل', 'nationality': 'الجنسية'},
        createCubit: (keys) => PassportScanCubit(reader: FakePassportReader(), picker: FakePassportPicker(), fieldKeys: keys),
      ),
      after: () async {
        await t.tap(find.text(lookupAppLocalizations(const Locale('ar')).passCapture));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await t.pump();
      },
    ),
  );

  // ── REP ──
  testGoldens(
    'REP-03 result',
    (t) => _shot(
      t,
      'rep_03_result',
      ReportResultScreen(
        request: const ReportRequest(spec: {}, title: 'تقرير الحجوزات', subtitle: 'سبتمبر ٢٠٢٦'),
        createCubit: () => ReportResultCubit(_Reports(), const ReportRequest(spec: {}, title: 't'))..load(),
      ),
    ),
  );
}
