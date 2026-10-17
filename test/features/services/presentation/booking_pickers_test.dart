// BOOK-02 … 08 pieces: traveler switcher, options sheet, date sheet, attachment
// cubit and slot, shortfall maths. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/dynamic_forms/domain/entities/dynamic_form_field.dart';
import 'package:seen_booking/features/requests/domain/entities/missing_document.dart';
import 'package:seen_booking/features/requests/domain/services/document_picker.dart';
import 'package:seen_booking/features/services/presentation/bloc/traveler_attachment_cubit.dart';
import 'package:seen_booking/features/services/presentation/widgets/seen_attachment_slot.dart';
import 'package:seen_booking/features/services/presentation/widgets/seen_booking_review_cards.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/services/presentation/widgets/seen_dynamic_field.dart';
import 'package:seen_booking/features/services/presentation/widgets/seen_options_sheet.dart';
import 'package:seen_booking/features/services/presentation/widgets/seen_traveler_chips.dart' show SeenTravelerState;
import 'package:seen_booking/features/services/presentation/widgets/seen_traveler_switcher.dart';

class _FakePicker implements DocumentPicker {
  _FakePicker(this.result);
  Either<Failure, PickedDocument?> result;

  @override
  Future<Either<Failure, PickedDocument?>> pick(DocumentSource source, {required List<String> allowedExtensions}) async =>
      result;
}

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

List<FieldOption> _many() => [
      for (var i = 0; i < 9; i++) FieldOption(value: 'v$i', label: 'خيار$i', description: 'd$i'),
    ];

void main() {
  group('SeenTravelerSwitcher', () {
    testWidgets('selects a traveler, adds, and disables "+" at the limit', (tester) async {
      int? selected;
      var added = 0;
      Widget build({VoidCallback? onAdd}) => SeenTravelerSwitcher(
            states: const [SeenTravelerState.done, SeenTravelerState.error],
            activeIndex: 0,
            onSelected: (i) => selected = i,
            onAdd: onAdd,
          );
      await _pump(tester, build(onAdd: () => added++));
      await tester.tap(find.text('مسافر ٢'));
      expect(selected, 1);
      await tester.tap(find.text('+'));
      expect(added, 1);

      await _pump(tester, build());
      await tester.tap(find.text('+'), warnIfMissed: false);
      expect(added, 1);
    });
  });

  group('options sheet', () {
    testWidgets('long lists get search; filtering, no-match state and pick', (tester) async {
      Object? got;
      await _pump(
        tester,
        SeenDynamicField(
          field: DynamicFormField(key: 'k-long', type: FieldType.select, label: 'الدولة', options: _many()),
          value: null,
          onChanged: (v) => got = v,
        ),
      );
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      expect(find.text('خيار3'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).last, 'zzz');
      await tester.pumpAndSettle();
      expect(find.textContaining('لا نتائج'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).last, 'd4');
      await tester.pumpAndSettle();
      await tester.tap(find.text('خيار4'));
      await tester.pumpAndSettle();
      expect(got, 'v4');
      expect(RecentOptions.of('k-long'), ['v4']);
    });

    testWidgets('short lists show no search box', (tester) async {
      await _pump(
        tester,
        SeenDynamicField(
          field: const DynamicFormField(
            key: 'k-short',
            type: FieldType.select,
            label: 'الجنس',
            options: [FieldOption(value: 'm', label: 'ذكر'), FieldOption(value: 'f', label: 'أنثى')],
          ),
          value: 'm',
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget); // only the form field itself
    });

    test('recents keep the newest three, newest first', () {
      for (final v in ['a', 'b', 'c', 'd', 'b']) {
        RecentOptions.remember('k-recent', v);
      }
      expect(RecentOptions.of('k-recent'), ['b', 'd', 'c']);
    });
  });

  group('date sheet', () {
    testWidgets('expiry sheet shows the 6-month rule and confirms the date', (tester) async {
      Object? got;
      await _pump(
        tester,
        SeenDynamicField(
          field: const DynamicFormField(
            key: 'exp',
            type: FieldType.date,
            label: 'تاريخ الانتهاء',
            dateConstraint: DateFieldConstraint.minMonthsInFuture,
          ),
          value: null,
          onChanged: (v) => got = v,
        ),
      );
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      expect(find.textContaining('٦ أشهر'), findsOneWidget);
      await tester.tap(find.text('تأكيد التاريخ'));
      await tester.pumpAndSettle();
      final picked = got as DateTime;
      final now = DateTime.now();
      expect(picked.isBefore(DateTime(now.year, now.month + 6, now.day)), isFalse);
    });
  });

  group('TravelerAttachmentCubit', () {
    PickedDocument doc(String name, int bytes) => PickedDocument(path: '/tmp/$name', fileName: name, sizeBytes: bytes);

    test('accepts a valid file, rejects wrong type and oversize, removes', () async {
      final picker = _FakePicker(Right(doc('p.pdf', 1000)));
      final cubit = TravelerAttachmentCubit(() => picker);
      await cubit.pick('t1', DocumentSource.file);
      expect(cubit.state.files['t1']?.fileName, 'p.pdf');

      picker.result = Right(doc('p.exe', 10));
      await cubit.pick('t2', DocumentSource.file);
      expect(cubit.state.error, AttachmentError.wrongType);
      expect(cubit.state.files.containsKey('t2'), isFalse);

      picker.result = Right(doc('big.png', attachmentMaxBytes + 1));
      await cubit.pick('t2', DocumentSource.gallery);
      expect(cubit.state.error, AttachmentError.tooLarge);

      picker.result = const Left(ServerFailure('no camera', code: 'PICKER_UNAVAILABLE'));
      await cubit.pick('t2', DocumentSource.camera);
      expect(cubit.state.error, AttachmentError.unavailable);

      picker.result = const Right(null); // cancelled: nothing changes
      await cubit.pick('t2', DocumentSource.file);
      expect(cubit.state.error, AttachmentError.unavailable);

      cubit.remove('t1');
      expect(cubit.state.files, isEmpty);
      await cubit.close();
    });

    testWidgets('slot: source sheet, picked file card, remove', (tester) async {
      final cubit = TravelerAttachmentCubit(() => _FakePicker(Right(doc('pass.jpg', 2048))));
      addTearDown(cubit.close);
      await _pump(
        tester,
        BlocProvider.value(
          value: cubit,
          child: const SeenAttachmentSlot(travelerId: 't1', title: 'نسخة جواز السفر', caption: 'cap'),
        ),
      );
      await tester.tap(find.text('نسخة جواز السفر'));
      await tester.pumpAndSettle();
      expect(find.text('الكاميرا'), findsOneWidget);
      await tester.tap(find.text('ملف'));
      await tester.pumpAndSettle();
      expect(find.text('pass.jpg'), findsOneWidget);
      expect(find.textContaining('لم يُرسل'), findsOneWidget);
      await tester.tap(find.text('حذف المرفق'));
      await tester.pumpAndSettle();
      expect(find.text('pass.jpg'), findsNothing);
    });
  });

  group('shortfall', () {
    test('credit remaining is limit minus used, never negative, null when unknown', () {
      const base = WalletBalance(
          availableCents: 0, holdCents: 0, creditLimitCents: 1000, currency: WalletCurrency.usd, creditUsedCents: 400);
      expect(base.creditRemainingCents, 600);
      expect(
          const WalletBalance(
                  availableCents: 0,
                  holdCents: 0,
                  creditLimitCents: 1000,
                  currency: WalletCurrency.usd,
                  creditUsedCents: 1500)
              .creditRemainingCents,
          0);
      expect(
          const WalletBalance(availableCents: 0, holdCents: 0, creditLimitCents: 1000, currency: WalletCurrency.usd)
              .creditRemainingCents,
          isNull);
    });

    testWidgets('card shows available, credit and the missing amount', (tester) async {
      await _pump(
        tester,
        const SeenShortfallCard(
          title: 'الرصيد لا يكفي',
          available: 10,
          availableLabel: 'المتاح',
          shortfall: 5,
          shortfallLabel: 'الناقص',
          creditRemaining: 2,
          creditLabel: 'ائتمان',
        ),
      );
      expect(find.text('الرصيد لا يكفي'), findsOneWidget);
      expect(find.textContaining('5'), findsOneWidget);
      expect(find.textContaining('2'), findsOneWidget);
    });
  });
}
