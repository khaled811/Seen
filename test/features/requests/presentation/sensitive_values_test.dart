// Sensitive traveler values on a request (PRIV-01..03): hidden by default, one reveal at a time
// for 30 seconds, a notice before the first one, and the rate-limit / no-permission / failure
// states. Arabic / RTL, 390 wide.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/requests/presentation/widgets/sensitive_values.dart';
import 'package:seen_booking/core/utils/latin_digits.dart';

import '../../../support/sensitive_values_fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _open(WidgetTester tester, FakeSensitiveValuesRepository repo, {bool introSeen = true}) async {
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
    home: Scaffold(
      body: SensitiveValuesScope(
        requestId: 'r1',
        repository: repo,
        introStore: FakeRevealIntroStore(isSeen: introSeen),
        child: const Column(children: [TravelerSensitiveBlock(index: 0), TravelerSensitiveBlock(index: 1)]),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

/// The reveal ("eye") buttons, in screen order.
Finder get _eyes => find.bySemanticsLabel(_l10n.privReveal);

void main() {
  final secureCalls = <bool>[];

  setUp(() {
    secureCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('seen_booking/secure_screen'),
      (call) async {
        secureCalls.add(call.arguments as bool);
        return null;
      },
    );
  });

  testWidgets('values show hidden, with an eye each and the logging note; nothing is drawn if they cannot load', (tester) async {
    await _open(tester, FakeSensitiveValuesRepository());
    expect(find.text('••••••4821'), findsOneWidget);
    expect(find.text('+966 5•• ••• 214'), findsOneWidget);
    expect(find.text('N08494821'), findsNothing);
    expect(_eyes, findsNWidgets(3));
    expect(find.text(_l10n.privMaskedNote), findsNWidgets(2));
  });

  testWidgets('no block at all when the load fails (the screen looks as it always did)', (tester) async {
    final repo = FakeSensitiveValuesRepository()..valuesResult = const Left(NetworkFailure('offline'));
    await _open(tester, repo);
    expect(find.byType(TravelerSensitiveBlock), findsNWidgets(2));
    expect(find.text(_l10n.privMaskedNote), findsNothing);
    expect(_eyes, findsNothing);
  });

  testWidgets('the eye reveals the clear text with a countdown and a Hide button, and the screen is flagged secure', (tester) async {
    final repo = FakeSensitiveValuesRepository();
    await _open(tester, repo);
    await tester.tap(_eyes.first);
    await tester.pump();
    await tester.pump();
    expect(repo.revealed, ['v-passport']);
    expect(find.text('N08494821'), findsOneWidget);
    expect(find.text('••••••4821'), findsNothing);
    expect(find.text(toArabicIndicDigits(_l10n.privCountdown(30))), findsOneWidget);
    expect(find.text(_l10n.privHide), findsOneWidget);
    expect(secureCalls, [true]);

    await tester.tap(find.text(_l10n.privHide));
    await tester.pump();
    expect(find.text('N08494821'), findsNothing);
    expect(find.text('••••••4821'), findsOneWidget);
    expect(secureCalls, [true, false]);
  });

  testWidgets('it hides by itself after 30 seconds', (tester) async {
    await _open(tester, FakeSensitiveValuesRepository());
    await tester.tap(_eyes.first);
    await tester.pump();
    await tester.pump();
    expect(find.text('N08494821'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('N08494821'), findsNothing);
    expect(find.text('••••••4821'), findsOneWidget);
  });

  testWidgets('only one value at a time, even across travelers', (tester) async {
    await _open(tester, FakeSensitiveValuesRepository());
    await tester.tap(_eyes.at(0));
    await tester.pump();
    await tester.pump();
    expect(find.text('N08494821'), findsOneWidget);
    await tester.tap(_eyes.at(0)); // the passport's eye is now "Hide", so the first eye left is the phone's
    await tester.pump();
    await tester.pump();
    expect(find.text('N08494821'), findsNothing);
    expect(find.text('+966512345214'), findsOneWidget);
    await tester.tap(find.text(_l10n.privHide));
    await tester.pump();
  });

  testWidgets('the first reveal shows the notice once; Cancel reveals nothing, Show goes on and the notice is not shown again', (tester) async {
    final repo = FakeSensitiveValuesRepository();
    await _open(tester, repo, introSeen: false);
    await tester.tap(_eyes.first);
    await tester.pumpAndSettle();
    expect(find.text(_l10n.privIntroTitle), findsOneWidget);
    expect(find.text(_l10n.privIntroLoggedTitle), findsOneWidget);
    expect(find.text(_l10n.privIntroCopyTitle), findsOneWidget);

    await tester.tap(find.text(_l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(repo.revealed, isEmpty);

    await tester.tap(_eyes.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.privReveal));
    await tester.pumpAndSettle();
    expect(repo.revealed, ['v-passport']);

    await tester.tap(find.text(_l10n.privHide));
    await tester.pump();
    await tester.tap(_eyes.first);
    await tester.pumpAndSettle();
    expect(find.text(_l10n.privIntroTitle), findsNothing, reason: 'shown only once');
    expect(repo.revealed, ['v-passport', 'v-passport']);
    await tester.tap(find.text(_l10n.privHide));
    await tester.pump();
  });

  testWidgets('a rate limit disables every eye and says when to try again', (tester) async {
    final repo = FakeSensitiveValuesRepository();
    repo.clearTexts['v-passport'] = const Left(ServerFailure('x', code: 'too_many_attempts', details: {'minutes': 12}));
    await _open(tester, repo);
    await tester.tap(_eyes.first);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining(toArabicIndicDigits(_l10n.privRateLimited(12)).substring(0, 20)), findsOneWidget);
    await tester.tap(_eyes.at(1), warnIfMissed: false);
    await tester.pump();
    expect(repo.revealed, ['v-passport'], reason: 'no further reveal while blocked');
  });

  testWidgets('no permission: a lock instead of the eye and the explanation row', (tester) async {
    final repo = FakeSensitiveValuesRepository();
    repo.clearTexts['v-passport'] = const Left(ServerFailure('x', code: 'permission_denied'));
    await _open(tester, repo);
    await tester.tap(_eyes.first);
    await tester.pump();
    await tester.pump();
    expect(find.text(_l10n.privNoPermissionTitle), findsOneWidget);
    expect(find.text(_l10n.privNoPermissionBody), findsOneWidget);
    expect(_eyes, findsNothing);
    expect(find.text('N08494821'), findsNothing);
  });

  testWidgets('another failure shows the retryable message and keeps the value hidden', (tester) async {
    final repo = FakeSensitiveValuesRepository();
    repo.clearTexts['v-passport'] = const Left(NetworkFailure('offline'));
    await _open(tester, repo);
    await tester.tap(_eyes.first);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining(_l10n.privLoadErrorTitle), findsOneWidget);
    expect(find.text('••••••4821'), findsOneWidget);
    expect(_eyes, findsNWidgets(3), reason: 'the person can try again');
  });

  testWidgets('leaving the screen hides a revealed value and clears the secure flag', (tester) async {
    await _open(tester, FakeSensitiveValuesRepository());
    await tester.tap(_eyes.first);
    await tester.pump();
    await tester.pump();
    expect(secureCalls, [true]);
    await tester.pumpWidget(const SizedBox());
    expect(secureCalls, [true, false]);
  });

  testWidgets('a second tap while a value is being fetched asks nothing more', (tester) async {
    final repo = FakeSensitiveValuesRepository()..hold = Completer<void>();
    await _open(tester, repo);
    await tester.tap(_eyes.first);
    await tester.pump();
    expect(find.bySemanticsLabel(_l10n.privRevealing), findsOneWidget);
    repo.hold!.complete();
    await tester.pump();
    await tester.pump();
    expect(repo.revealed, ['v-passport']);
    await tester.tap(find.text(_l10n.privHide));
    await tester.pump();
  });
}
