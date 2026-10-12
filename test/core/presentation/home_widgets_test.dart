// Home building blocks: balance card, service tile, promo banner, countdown
// pill, bottom navigation and the request summary card. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/presentation/foundation/seen_icons.dart';
import 'package:seen_booking/core/presentation/foundation/seen_strings.dart';
import 'package:seen_booking/core/presentation/foundation/seen_vectors.dart';
import 'package:seen_booking/core/presentation/widgets/balance_card.dart';
import 'package:seen_booking/core/presentation/widgets/chrome.dart';
import 'package:seen_booking/core/presentation/widgets/promo_banner.dart';
import 'package:seen_booking/core/presentation/widgets/service_tile.dart';
import 'package:seen_booking/core/presentation/widgets/status.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/seen_colors.dart';
import 'package:seen_booking/features/requests/presentation/widgets/request_status_seen_mapping.dart';
import 'package:seen_booking/features/requests/presentation/widgets/seen_request_summary_card.dart';
import 'package:seen_booking/core/constants/enums.dart';

Future<void> _pump(WidgetTester tester, Widget child, {Locale locale = const Locale('ar')}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(14), child: SingleChildScrollView(child: child))),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('balance card shows the amount LTR and the eye toggle masks every amount', (tester) async {
    await _pump(
      tester,
      SeenBalanceCard(
        available: 1532,
        hold: 210,
        creditLimit: 2000,
        caption: 'رصيد دائن',
        holdLabel: (a) => 'محجوز $a',
        creditLimitLabel: (a) => 'الحد الائتماني $a',
        showSemanticLabel: 'إظهار الرصيد',
        hideSemanticLabel: 'إخفاء الرصيد',
      ),
    );
    expect(find.text('1,532.00 USD'), findsOneWidget);
    expect(find.textContaining('محجوز'), findsOneWidget);
    expect(find.textContaining('الحد الائتماني'), findsOneWidget);

    await tester.tap(find.byIcon(SeenIcons.eye));
    await tester.pump();
    expect(find.text('1,532.00 USD'), findsNothing);
    expect(find.text('••••••'), findsOneWidget);
    expect(find.byIcon(SeenIcons.eyeSlash), findsOneWidget);
  });

  testWidgets('service tile taps through; the soon tile does not', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      Column(
        children: [
          SeenServiceTile(label: 'دخول مصر', iconAsset: SeenVectors.iconEgyptEntry, onTap: () => taps++),
          SeenServiceTile(
            label: 'فنادق',
            iconAsset: SeenVectors.iconHotel,
            soon: true,
            soonLabel: 'قريبًا',
            onTap: () => taps += 100,
          ),
        ],
      ),
    );
    await tester.tap(find.text('دخول مصر'));
    await tester.tap(find.text('فنادق'), warnIfMissed: false);
    expect(taps, 1);
    expect(find.text('قريبًا'), findsOneWidget);
  });

  testWidgets('promo banner renders its copy and fires the action', (tester) async {
    var fired = 0;
    await _pump(
      tester,
      SeenPromoBanner(badge: 'جديد', title: 'عنوان', subtitle: 'وصف', actionLabel: 'اطلب الآن', onAction: () => fired++),
    );
    expect(find.text('جديد'), findsOneWidget);
    expect(find.text('عنوان'), findsOneWidget);
    await tester.tap(find.text('اطلب الآن'));
    expect(fired, 1);
  });

  testWidgets('countdown pill shows its label on the status colors', (tester) async {
    await _pump(tester, const SeenCountdownPill(label: 'يتبقى ٥٢ ساعة', state: SeenCountdownState.urgent));
    expect(find.text('يتبقى ٥٢ ساعة'), findsOneWidget);
    final box = tester.widget<DecoratedBox>(find
        .descendant(of: find.byType(SeenCountdownPill), matching: find.byType(DecoratedBox))
        .first);
    expect((box.decoration as BoxDecoration).color, SeenRequestStatus.deadlineUnder24h.colors.bg);
  });

  testWidgets('bottom navigation: five Figma tabs with SVG icons and selection callback', (tester) async {
    int? selected;
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
        home: Scaffold(bottomNavigationBar: SeenBottomNav(selectedIndex: 0, onSelected: (i) => selected = i)),
      ),
    );
    await tester.pump();
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byType(SvgPicture), findsNWidgets(5));
    for (final label in ['الرئيسية', 'طلباتي', 'المحفظة', 'الوكلاء', 'حسابي']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('المحفظة'));
    expect(selected, 2);
  });

  testWidgets('request summary card: status chip, step label and reference; countdown replaces the date', (tester) async {
    final deadline = DateTime.now().add(const Duration(hours: 52, minutes: 30));
    await _pump(
      tester,
      Column(
        children: [
          SeenRequestSummaryCard(
            title: 'دخول مصر',
            subtitle: 'مسافران',
            status: RequestStatus.infoRequired.toSeenRequestStatus(slaDeadline: deadline),
            progress: RequestStatus.infoRequired.progress,
            reference: 'SB-20476',
            dateLabel: '12/11/2026',
            slaDeadline: deadline,
          ),
          SeenRequestSummaryCard(
            title: 'تأشيرة السعودية',
            subtitle: 'مسافر واحد',
            status: RequestStatus.completed.toSeenRequestStatus(),
            progress: RequestStatus.completed.progress,
            reference: 'SB-20470',
            dateLabel: '12/11/2026',
          ),
        ],
      ),
    );

    expect(find.text('بانتظار مستند'), findsOneWidget);
    expect(find.text('مراجعة المستندات · ٢ من ٥'), findsOneWidget);
    expect(find.text('SB-20476'), findsOneWidget);
    expect(find.byType(SeenCountdownPill), findsOneWidget);
    expect(find.textContaining('يتبقى'), findsOneWidget);

    expect(find.text('مكتمل'), findsOneWidget);
    expect(find.text('صادرة · ٥ من ٥'), findsOneWidget);
    expect(find.text('12/11/2026'), findsOneWidget); // only the completed card shows a date
  });

  testWidgets('SeenStrings numerals: Arabic-Indic in Arabic, Latin in English', (tester) async {
    Future<String> numeral(String code) async {
      late String out;
      await tester.pumpWidget(Localizations(
        locale: Locale(code),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(builder: (context) {
          out = SeenStrings.of(context).numeral(1234);
          return const SizedBox();
        }),
      ));
      return out;
    }

    expect(await numeral('ar'), '١٬٢٣٤');
    expect(await numeral('en'), '1,234');
  });
}
