// New shared / review widgets from the booking flow. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/presentation/widgets/actions.dart' show SeenRoundIconButton;
import 'package:seen_booking/core/presentation/widgets/dropzone.dart';
import 'package:seen_booking/core/presentation/widgets/form_stepper.dart';
import 'package:seen_booking/core/presentation/widgets/screen_header.dart';
import 'package:seen_booking/core/presentation/widgets/search_field.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/dynamic_forms/domain/entities/dynamic_form_field.dart';
import 'package:seen_booking/features/services/presentation/widgets/seen_booking_review_cards.dart';
import 'package:seen_booking/features/services/presentation/widgets/seen_dynamic_field.dart';

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
      home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('form stepper shows every label and numbers the upcoming steps in Arabic-Indic', (tester) async {
    await _pump(tester, const SeenFormStepper(labels: ['الخدمة', 'المسافرون', 'المراجعة'], current: 1));
    for (final l in ['الخدمة', 'المسافرون', 'المراجعة']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('٢'), findsOneWidget); // current
    expect(find.text('٣'), findsOneWidget); // upcoming
    expect(find.text('١'), findsNothing); // done step shows a check instead
    expect(find.byIcon(Icons.check), findsNothing); // (Phosphor check, not the Material one)
  });

  testWidgets('dropzone fires its tap and exposes title + caption', (tester) async {
    var taps = 0;
    await _pump(tester, SeenDropzone(title: 'نسخة جواز السفر', caption: 'الإرفاق قريبًا', onTap: () => taps++));
    expect(find.text('نسخة جواز السفر'), findsOneWidget);
    await tester.tap(find.text('الإرفاق قريبًا'));
    expect(taps, 1);
  });

  testWidgets('search field reports edits', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? last;
    await _pump(tester, SeenSearchField(hint: 'ابحث عن خدمة', controller: controller, onChanged: (v) => last = v));
    await tester.enterText(find.byType(TextField), 'abc');
    expect(last, 'abc');
  });

  testWidgets('screen header: back pops and the title/subtitle are centered text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const Scaffold(body: SeenScreenHeader(title: 'عنوان', subtitle: 'الخطوة ٢ من ٣')),
            )),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('عنوان'), findsOneWidget);
    expect(find.text('الخطوة ٢ من ٣'), findsOneWidget);

    await tester.tap(find.byType(SeenRoundIconButton));
    await tester.pumpAndSettle();
    expect(find.text('عنوان'), findsNothing);
  });

  group('review cards', () {
    testWidgets('fees card: "n × unit" and the total are left-to-right figures', (tester) async {
      await _pump(tester, const SeenReviewFeesCard(travelerCount: 3, perTravelerPrice: 50, totalLabel: 'الإجمالي'));
      expect(find.text('3 × 50.00 USD'), findsOneWidget);
      expect(find.text('150.00 USD'), findsOneWidget);
      expect(find.text('رسوم الخدمة × ٣'), findsOneWidget);
    });

    testWidgets('wallet hold card shows the balance left after booking', (tester) async {
      await _pump(
        tester,
        SeenWalletHoldCard(
          charge: 150,
          available: 1532,
          loading: false,
          titleBuilder: (a) => 'سيتم حجز $a',
          note: 'ملاحظة',
          afterLabel: 'المتاح بعد الحجز',
        ),
      );
      expect(find.textContaining('سيتم حجز'), findsOneWidget);
      expect(find.text('المتاح بعد الحجز'), findsOneWidget);
      expect(find.text('1,382.00 USD'), findsOneWidget);
    });

    testWidgets('wallet hold card flags an insufficient balance', (tester) async {
      await _pump(
        tester,
        SeenWalletHoldCard(
          charge: 150,
          available: 100,
          loading: false,
          titleBuilder: (a) => 'سيتم حجز $a',
          note: 'ملاحظة',
          afterLabel: 'المتاح بعد الحجز',
        ),
      );
      expect(find.text('الرصيد غير كافٍ'), findsOneWidget);
      expect(find.text('المتاح بعد الحجز'), findsNothing);
    });

    testWidgets('confirm check toggles', (tester) async {
      var value = false;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) =>
              SeenConfirmCheck(value: value, label: 'أؤكد', onChanged: (v) => setState(() => value = v)),
        ),
      );
      await tester.tap(find.text('أؤكد'));
      await tester.pump();
      expect(value, isTrue);
    });

    testWidgets('travelers card lists numbered names and passports', (tester) async {
      await _pump(
        tester,
        const SeenReviewTravelersCard(travelers: [
          SeenReviewTraveler(name: 'AHMED SALEH', passport: 'A1234567'),
          SeenReviewTraveler(name: 'SARA ALI'),
        ]),
      );
      expect(find.text('AHMED SALEH'), findsOneWidget);
      expect(find.text('A1234567'), findsOneWidget);
      expect(find.text('٢'), findsOneWidget);
    });
  });

  group('SeenDynamicField', () {
    const text = DynamicFormField(key: 'name', type: FieldType.text, label: 'الاسم');
    const date = DynamicFormField(key: 'dob', type: FieldType.date, label: 'تاريخ الميلاد');
    const select = DynamicFormField(
      key: 'gender',
      type: FieldType.select,
      label: 'الجنس',
      options: [FieldOption(value: 'm', label: 'ذكر'), FieldOption(value: 'f', label: 'أنثى')],
    );

    testWidgets('text: shows the label and forwards edits', (tester) async {
      Object? got;
      await _pump(tester, SeenDynamicField(field: text, value: 'x', onChanged: (v) => got = v));
      expect(find.text('الاسم'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Ali');
      expect(got, 'Ali');
    });

    testWidgets('text: shows the validation error under the field', (tester) async {
      await _pump(tester, SeenDynamicField(field: text, value: null, errorText: 'مطلوب', onChanged: (_) {}));
      expect(find.text('مطلوب'), findsOneWidget);
    });

    testWidgets('date: renders the value and follows external changes', (tester) async {
      var value = DateTime(2029, 4, 18);
      late StateSetter set;
      await _pump(
        tester,
        StatefulBuilder(builder: (context, setState) {
          set = setState;
          return SeenDynamicField(field: date, value: value, onChanged: (_) {});
        }),
      );
      expect(find.text('2029 / 04 / 18'), findsOneWidget);
      set(() => value = DateTime(2030, 1, 2));
      await tester.pump();
      expect(find.text('2030 / 01 / 02'), findsOneWidget);
    });

    testWidgets('select: opens the options sheet and returns the picked value', (tester) async {
      Object? got;
      await _pump(tester, SeenDynamicField(field: select, value: null, onChanged: (v) => got = v));
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أنثى'));
      await tester.pumpAndSettle();
      expect(got, 'f');
    });
  });
}
