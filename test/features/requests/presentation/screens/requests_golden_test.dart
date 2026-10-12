// Golden coverage for the Requests list/detail redesign (design/requests/SPEC.md §7).
//
// These goldens assemble the SAME public design-system widgets the real
// screens use (SeenRequestCard, SeenSegmentChips, SeenStatusBadge,
// SeenSlaTag, SeenStatusStepper, SeenListGroup, SeenTopBar), fed with fixed
// SPEC-matching fixture data, rather than driving RequestsDashboardScreen/
// RequestDetailScreen directly — those own screens create their Bloc via
// InjectionContainer.instance.createRequestsBloc(), which is wired to a
// real (placeholder) GraphQL endpoint with no test-time override seam, so
// their content isn't deterministic enough for pixel goldens. The private
// `_DashboardBody`/`_DetailBody` classes that hold the actual layout also
// aren't reachable from a separate test library. This still exercises the
// exact widgets/theme/tokens the real screens render with — see the
// session's final comparison notes for what this does and doesn't prove.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/presentation/foundation/seen_status.dart';
import 'package:seen_booking/core/presentation/widgets/avatar.dart';
import 'package:seen_booking/core/presentation/widgets/chrome.dart';
import 'package:seen_booking/core/presentation/widgets/filters.dart';
import 'package:seen_booking/core/presentation/widgets/status.dart';
import 'package:seen_booking/core/presentation/widgets/steppers.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/seen_dimensions.dart';
import 'package:seen_booking/features/requests/presentation/widgets/seen_request_card.dart';

const _surfaceSize = Size(390, 844);

Widget _rtl(Widget child, {required Brightness brightness}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

class _RequestsListPreview extends StatelessWidget {
  const _RequestsListPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SeenTopBar.inner(title: 'طلباتي'),
      body: Column(
        children: [
          const SizedBox(height: SeenSpace.s2),
          SeenSegmentChips(
            items: const [
              SeenSegment(label: 'الكل', count: 48),
              SeenSegment(label: 'قيد المراجعة', count: 12),
              SeenSegment(label: 'مطلوب إجراء', count: 3, alert: true),
              SeenSegment(label: 'مكتمل', count: 33),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
          const SizedBox(height: SeenSpace.s2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(SeenSpace.s4, 0, SeenSpace.s4, SeenSpace.s4),
              children: const [
                SeenRequestCard(
                  reference: 'EG-MI-2026-003190',
                  service: 'موافقة الاستخبارات العسكرية',
                  travelers: 2,
                  date: '25/09/2026',
                  status: SeenStatus.action,
                  amount: 400,
                  note: 'مطلوب نسخة أوضح من جواز السفر',
                ),
                SizedBox(height: SeenSpace.s3),
                SeenRequestCard(
                  reference: 'EG-NS-2026-004718',
                  service: 'موافقة الأمن الوطني',
                  travelers: 1,
                  date: '24/09/2026',
                  status: SeenStatus.review,
                  amount: 270,
                ),
                SizedBox(height: SeenSpace.s3),
                SeenRequestCard(
                  reference: 'EG-NS-2026-004602',
                  service: 'موافقة الأمن الوطني',
                  travelers: 3,
                  date: '20/09/2026',
                  status: SeenStatus.completed,
                  amount: 810,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsEmptyPreview extends StatelessWidget {
  const _RequestsEmptyPreview();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: SeenTopBar.inner(title: 'طلباتي'),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(SeenSpace.s6),
          child: Text('لا توجد طلبات مطابقة', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _RequestDetailPreview extends StatelessWidget {
  const _RequestDetailPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SeenTopBar.inner(title: 'تفاصيل الطلب', subtitle: 'EG-MI-2026-003190'),
      body: ListView(
        padding: const EdgeInsets.all(SeenSpace.s4),
        children: const [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SeenStatusBadge(status: SeenStatus.review),
              SeenSlaTag.fixed(remaining: Duration(hours: 52), totalHours: 72),
            ],
          ),
          SizedBox(height: SeenSpace.s3),
          Text('موافقة الاستخبارات العسكرية'),
          SizedBox(height: SeenSpace.s6),
          SeenSectionHeader(title: 'مراحل الطلب'),
          SeenStatusStepper(
            current: 2,
            steps: [
              SeenStep(title: 'تم الإرسال وحجز المبلغ', meta: '27/09 · 09:15'),
              SeenStep(title: 'التحقق من المستندات', meta: '27/09 · 11:02'),
              SeenStep(title: 'قيد المراجعة لدى الجهة', meta: 'متوقع خلال 52 ساعة'),
              SeenStep(title: 'صدور الموافقات والخصم النهائي'),
            ],
          ),
          SizedBox(height: SeenSpace.s6),
          SeenSectionHeader(title: 'المسافرون'),
          SeenListGroup(children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: SeenSpace.s3),
              child: Row(children: [
                SeenAvatar(initial: '1'),
                SizedBox(width: SeenSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MOHAMMED ALI SALEH', textDirection: TextDirection.ltr),
                      Text('08A1234', textDirection: TextDirection.ltr),
                    ],
                  ),
                ),
                SizedBox(width: SeenSpace.s2),
                SeenStatusBadge(status: SeenStatus.approved, dense: true),
              ]),
            ),
          ]),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(loadAppFonts);

  testGoldens('requests list — light', (tester) async {
    await tester.pumpWidgetBuilder(
      const _RequestsListPreview(),
      wrapper: (child) => _rtl(child, brightness: Brightness.light),
      surfaceSize: _surfaceSize,
    );
    await screenMatchesGolden(tester, 'requests_list_light');
  });

  testGoldens('requests list — dark', (tester) async {
    await tester.pumpWidgetBuilder(
      const _RequestsListPreview(),
      wrapper: (child) => _rtl(child, brightness: Brightness.dark),
      surfaceSize: _surfaceSize,
    );
    await screenMatchesGolden(tester, 'requests_list_dark');
  });

  testGoldens('requests list — empty state', (tester) async {
    await tester.pumpWidgetBuilder(
      const _RequestsEmptyPreview(),
      wrapper: (child) => _rtl(child, brightness: Brightness.light),
      surfaceSize: _surfaceSize,
    );
    await screenMatchesGolden(tester, 'requests_list_empty');
  });

  testGoldens('request detail — light', (tester) async {
    await tester.pumpWidgetBuilder(
      const _RequestDetailPreview(),
      wrapper: (child) => _rtl(child, brightness: Brightness.light),
      surfaceSize: _surfaceSize,
    );
    await screenMatchesGolden(tester, 'request_detail_light');
  });

  testGoldens('request detail — dark', (tester) async {
    await tester.pumpWidgetBuilder(
      const _RequestDetailPreview(),
      wrapper: (child) => _rtl(child, brightness: Brightness.dark),
      surfaceSize: _surfaceSize,
    );
    await screenMatchesGolden(tester, 'request_detail_dark');
  });
}
