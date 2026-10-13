// Relative time and unread caption used by the notification cards (Arabic / English).

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/presentation/foundation/seen_strings.dart';

Future<SeenStrings> _strings(WidgetTester tester, Locale locale) async {
  late SeenStrings s;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(builder: (context) {
      s = SeenStrings.of(context);
      return const SizedBox();
    }),
  ));
  return s;
}

void main() {
  final now = DateTime(2026, 11, 12, 15, 0);

  testWidgets('Arabic: minutes, hours, yesterday and older', (tester) async {
    final s = await _strings(tester, const Locale('ar'));
    expect(s.timeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'الآن');
    expect(s.timeAgo(now.subtract(const Duration(minutes: 10)), now: now), 'قبل ١٠ دقائق');
    expect(s.timeAgo(now.subtract(const Duration(minutes: 2)), now: now), 'قبل دقيقتين');
    expect(s.timeAgo(now.subtract(const Duration(hours: 1)), now: now), 'قبل ساعة');
    expect(s.timeAgo(now.subtract(const Duration(hours: 3)), now: now), 'قبل ٣ ساعات');
    expect(s.timeAgo(DateTime(2026, 11, 11, 20), now: now), 'أمس');
    expect(s.timeAgo(DateTime(2026, 11, 8, 9), now: now), '٨ نوفمبر');
    expect(s.unreadCount(3), '٣ غير مقروءة');
  });

  testWidgets('English wording', (tester) async {
    final s = await _strings(tester, const Locale('en'));
    expect(s.timeAgo(now.subtract(const Duration(minutes: 10)), now: now), '10 min ago');
    expect(s.timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
    expect(s.unreadCount(3), '3 unread');
  });
}
