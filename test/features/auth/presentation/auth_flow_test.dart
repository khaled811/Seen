// Auth cluster (Figma screens 01-04): boot -> Welcome -> Login -> back, the
// login field rules, and the OTP header. Uses the real AuthBloc with secure
// storage stubbed (same approach as test/widget_test.dart); no network call is
// ever made because no sign-in is submitted successfully.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seen_booking/app.dart';
import 'package:seen_booking/core/di/injection_container.dart';
import 'package:seen_booking/core/presentation/widgets/actions.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:seen_booking/features/auth/presentation/screens/otp_verification_screen.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
    InjectionContainer.instance.init();
  });

  Future<void> boot(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
  }

  testWidgets('boots to Welcome; Sign in opens Login; back returns to Welcome', (tester) async {
    await boot(tester);
    expect(find.text('أهلًا بك في سين أعمال'), findsOneWidget);

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.text('رقم الجوال'), findsOneWidget);
    expect(find.text('أهلًا بك في سين أعمال'), findsNothing);

    await tester.tap(find.byType(SeenRoundIconButton));
    await tester.pumpAndSettle();
    expect(find.text('أهلًا بك في سين أعمال'), findsOneWidget);
  });

  testWidgets('Login: empty submit shows required errors, bad phone shows the phone error', (tester) async {
    await boot(tester);
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('دخول'));
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    expect(find.text('هذا الحقل مطلوب.'), findsNWidgets(2));

    await tester.enterText(find.byType(TextFormField).first, '123');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل رقم جوال صحيحًا.'), findsOneWidget);
  });

  testWidgets('Login: Arabic-Indic digits are converted to Latin as typed', (tester) async {
    await boot(tester);
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '٧٧١٢٣٤٥٦٧');
    await tester.pump();
    expect(find.text('771234567'), findsOneWidget);
    expect(find.text('+967'), findsOneWidget); // country context prefix
  });

  testWidgets('OTP header names the masked phone and shows the m:ss countdown', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      BlocProvider<AuthBloc>(
        create: (_) => InjectionContainer.instance.createAuthBloc(),
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light,
          home: const OtpVerificationScreen(resendCooldownSeconds: 42, identifier: '+967771234567'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('رمز التحقق'), findsOneWidget);
    expect(find.text('أرسلنا رمزًا من ٦ أرقام إلى +96777 ••• 4567'), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget);

    // Dispose the screen so its countdown timer is cancelled before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
