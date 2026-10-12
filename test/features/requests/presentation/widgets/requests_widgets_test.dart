// Requests cluster widgets: deadline counter, stepper states, empty state and
// the documents sheet. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/presentation/foundation/seen_vectors.dart';
import 'package:seen_booking/core/presentation/widgets/empty_state.dart';
import 'package:seen_booking/core/presentation/widgets/steppers.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/seen_colors.dart';
import 'package:seen_booking/features/requests/domain/entities/request_detail.dart';
import 'package:seen_booking/features/requests/presentation/widgets/request_documents_sheet.dart';
import 'package:seen_booking/features/requests/presentation/widgets/seen_deadline_card.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
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
      home: home,
    ),
  );
  await tester.pump();
}

RequestDetail _detail({String? url, RequestStatus status = RequestStatus.completed}) => RequestDetail(
      id: '1',
      referenceId: 'SB-1',
      serviceName: 'خدمة',
      status: status,
      totalPriceCents: 15000,
      submittedAt: DateTime(2026, 11, 12),
      travelers: const [],
      timeline: const [],
      outputDocumentUrl: url,
    );

void main() {
  group('SeenDeadlineCard', () {
    testWidgets('shows HH:MM:SS left-to-right and ticks every second', (tester) async {
      var now = DateTime(2026, 11, 12, 9);
      final deadline = now.add(const Duration(hours: 46, minutes: 12, seconds: 30));
      await _pump(
        tester,
        Scaffold(
          body: SeenDeadlineCard(
            deadline: deadline,
            clock: () => now,
            title: 'المهلة المتبقية',
            subtitle: 'لرفع المستندات',
            expiredLabel: 'انتهت',
          ),
        ),
      );
      expect(find.text('46:12:30'), findsOneWidget);

      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1)); // timer tick reads the clock
      expect(find.text('46:12:28'), findsOneWidget);

      // Unmount: the periodic timer must be cancelled (no pending timers at test end).
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an elapsed deadline shows the expired label instead of a counter', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: SeenDeadlineCard(
            deadline: DateTime.now().subtract(const Duration(minutes: 5)),
            title: 'المهلة المتبقية',
            subtitle: 'لرفع المستندات',
            expiredLabel: 'انتهت المهلة',
          ),
        ),
      );
      expect(find.text('انتهت المهلة'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('SeenStatusStepper: done steps get a check, one current marker, the rest hollow', (tester) async {
    const steps = [
      SeenStep(title: 'أ', meta: 'm1'),
      SeenStep(title: 'ب'),
      SeenStep(title: 'ج'),
      SeenStep(title: 'د'),
    ];
    await _pump(tester, const Scaffold(body: SeenStatusStepper(steps: steps, current: 2)));
    expect(find.byType(Icon), findsNWidgets(2)); // checks on steps 1 and 2
    expect(find.text('m1'), findsOneWidget);

    // current == steps.length marks every step done.
    await _pump(tester, const Scaffold(body: SeenStatusStepper(steps: steps, current: 4)));
    expect(find.byType(Icon), findsNWidgets(4));
  });

  testWidgets('SeenEmptyState shows its copy and fires the primary action', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      Scaffold(
        body: SeenEmptyState(
          iconAsset: SeenVectors.iconRequests,
          title: 'لا توجد طلبات بعد',
          message: 'ابدأ أول طلب',
          actionLabel: 'اطلب خدمة',
          onAction: () => taps++,
        ),
      ),
    );
    expect(find.text('لا توجد طلبات بعد'), findsOneWidget);
    await tester.tap(find.text('اطلب خدمة'));
    expect(taps, 1);
  });

  group('showRequestDocumentsSheet', () {
    Future<void> open(WidgetTester tester, RequestDetail detail) async {
      await _pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRequestDocumentsSheet(context, detail),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('without a document it explains when documents appear', (tester) async {
      await open(tester, _detail());
      expect(find.text('المستندات'), findsOneWidget);
      expect(find.textContaining('لا توجد مستندات'), findsOneWidget);
    });

    testWidgets('a completed request with an output URL offers copying the link', (tester) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await open(tester, _detail(url: 'https://files.example/approvals.pdf'));
      expect(find.text('مستند الموافقات'), findsOneWidget);
      await tester.tap(find.text('نسخ الرابط'));
      await tester.pump();
      expect(copied, 'https://files.example/approvals.pdf');
    });

    testWidgets('an output URL on a not-yet-completed request is ignored', (tester) async {
      await open(tester, _detail(url: 'https://files.example/x.pdf', status: RequestStatus.processing));
      expect(find.text('مستند الموافقات'), findsNothing);
      expect(find.textContaining('لا توجد مستندات'), findsOneWidget);
    });
  });

  test('stepper marker palette is the Figma violet', () {
    expect(SeenBrand.violet, const Color(0xFF7B52F5));
  });
}
