// Booking success / receipt (Figma BOOK-01). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/navigation/shell_tab_request.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/services/presentation/screens/booking_success_screen.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    int? balanceAfterCents = 138200,
    String? referenceCode = 'SB-20489',
    int? heldCents = 15000,
    bool holdDeferred = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ShellTabRequest.notifier.value = null;
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
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => BookingSuccessScreen(
                requestId: 'req-internal-id',
                referenceCode: referenceCode,
                serviceName: 'تأشيرة السعودية',
                travelerCount: 3,
                heldCents: heldCents,
                balanceAfterCents: balanceAfterCents,
                holdDeferred: holdDeferred,
              ),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the receipt rows, the hold note and both secondary actions', (tester) async {
    await open(tester);
    expect(find.text('تم إرسال الطلب'), findsOneWidget);
    expect(find.text('SB-20489'), findsOneWidget);
    expect(find.text('تأشيرة السعودية'), findsOneWidget);
    expect(find.text('٣'), findsOneWidget);
    expect(find.textContaining('150.00'), findsOneWidget);
    expect(find.textContaining('1,382.00'), findsOneWidget);
    expect(find.textContaining('المبلغ محجوز وليس مخصومًا'), findsOneWidget);
    expect(find.text('مشاركة الإيصال'), findsOneWidget);
    expect(find.text('تنزيل PDF'), findsOneWidget);

    // Not built yet: says so instead of pretending.
    await tester.tap(find.text('تنزيل PDF'));
    await tester.pump();
    expect(find.textContaining('ستتوفر قريبًا'), findsOneWidget);
  });

  testWidgets('the balance row is hidden when the wallet was not loaded', (tester) async {
    await open(tester, balanceAfterCents: null);
    expect(find.text('الرصيد المتاح بعد الحجز'), findsNothing);
    expect(find.text('المبلغ المحجوز'), findsOneWidget);
  });

  testWidgets('the confirmation is the reference code, never the internal request id', (tester) async {
    await open(tester);
    expect(find.text('SB-20489'), findsOneWidget);
    expect(find.text('req-internal-id'), findsNothing);
  });

  testWidgets('a reference that has not appeared yet says so (no id in its place, nothing to copy)', (tester) async {
    await open(tester, referenceCode: null);
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l10n.bookingReferencePending), findsOneWidget);
    expect(find.text('req-internal-id'), findsNothing);
    expect(find.text(l10n.bookingReceiptCopy), findsNothing);
  });

  testWidgets('a service that waits for approval holds nothing: no held rows, the deferred note instead', (tester) async {
    await open(tester, heldCents: null, balanceAfterCents: null, holdDeferred: true);
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(find.text('المبلغ المحجوز'), findsNothing);
    expect(find.text(l10n.reviewHoldDeferredNote), findsOneWidget);
    expect(find.textContaining('المبلغ محجوز وليس مخصومًا'), findsNothing);
  });

  testWidgets('"Follow request" leaves the receipt and asks the shell for the Requests tab', (tester) async {
    await open(tester);
    await tester.tap(find.text('متابعة الطلب'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(ShellTabRequest.notifier.value, 1);
  });

  testWidgets('system back leaves to Home instead of the completed form', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(ShellTabRequest.notifier.value, 0);
  });
}
