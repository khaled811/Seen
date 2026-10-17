// Contact support before sign-in (Figma SUP-05). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/support/domain/entities/support_contacts.dart';
import 'package:seen_booking/features/support/presentation/widgets/contact_support_sheet.dart';

void main() {
  Future<void> open(WidgetTester tester, SupportContacts contacts) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
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
            onPressed: () => showContactSupportSheet(context, contacts: contacts),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  test('channels: any one makes the sheet useful, blanks do not count', () {
    expect(const SupportContacts().hasChannels, false);
    expect(const SupportContacts(phone: '  ').hasChannels, false);
    expect(const SupportContacts(email: 'a@b.c').hasChannels, true);
  });

  testWidgets('lists the configured channels with their hours', (tester) async {
    await open(
      tester,
      const SupportContacts(whatsapp: '+967 1 111 111', phone: '+967 1 222 222', email: 'help@x.test', hours: 'من ٨ إلى ١٠'),
    );
    expect(find.text('تواصل مع الدعم'), findsOneWidget);
    expect(find.text('من ٨ إلى ١٠'), findsOneWidget);
    expect(find.text('واتساب'), findsOneWidget);
    expect(find.text('+967 1 111 111'), findsOneWidget);
    expect(find.text('اتصال مباشر'), findsOneWidget);
    expect(find.text('بريد إلكتروني'), findsOneWidget);
    expect(find.text('help@x.test'), findsOneWidget);
  });

  testWidgets('a channel that is not configured is left out', (tester) async {
    await open(tester, const SupportContacts(email: 'help@x.test'));
    expect(find.text('واتساب'), findsNothing);
    expect(find.text('اتصال مباشر'), findsNothing);
    expect(find.text('بريد إلكتروني'), findsOneWidget);
  });

  testWidgets('tapping a row copies its value and says so', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      },
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await open(tester, const SupportContacts(phone: '+967 1 222 222', email: 'help@x.test'));
    await tester.tap(find.text('اتصال مباشر'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(copied, '+967 1 222 222');
    expect(find.text('تم نسخ الرقم.'), findsOneWidget);
    await tester.tap(find.text('بريد إلكتروني'));
    await tester.pump();
    expect(copied, 'help@x.test');
  });

  testWidgets('with no channels it says they are available after sign-in', (tester) async {
    await open(tester, const SupportContacts());
    expect(find.text('يمكنك التواصل مع الدعم من داخل التطبيق بعد تسجيل الدخول.'), findsOneWidget);
    expect(find.text('واتساب'), findsNothing);
  });
}
