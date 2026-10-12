// Golden coverage for the Requests list / empty / tracking screens (Figma 06,
// 18, 07).
//
// These goldens assemble the SAME public widgets the real screens use
// (SeenRequestSummaryCard, SeenStatCard, SeenSegmentChips, SeenEmptyState,
// SeenRequestTicket, SeenStatusStepper, SeenRoundIconButton), fed with fixed
// fixture data, rather than driving RequestsDashboardScreen /
// RequestDetailScreen directly: those create their Bloc via
// InjectionContainer.instance.createRequestsBloc(), which is wired to a real
// (placeholder) GraphQL endpoint with no test-time override seam, and the
// layout lives in private classes. Live-ticking pieces (the HH:MM:SS deadline
// counter) are deliberately left out so the pixels are deterministic.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/presentation/foundation/seen_icons.dart';
import 'package:seen_booking/core/presentation/foundation/seen_strings.dart';
import 'package:seen_booking/core/presentation/foundation/seen_vectors.dart';
import 'package:seen_booking/core/presentation/widgets/actions.dart';
import 'package:seen_booking/core/presentation/widgets/empty_state.dart';
import 'package:seen_booking/core/presentation/widgets/filters.dart';
import 'package:seen_booking/core/presentation/widgets/screen_background.dart';
import 'package:seen_booking/core/presentation/widgets/stat_card.dart';
import 'package:seen_booking/core/presentation/widgets/steppers.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/seen_colors.dart';
import 'package:seen_booking/core/theme/seen_dimensions.dart';
import 'package:seen_booking/core/theme/seen_format.dart';
import 'package:seen_booking/core/theme/seen_typography.dart';
import 'package:seen_booking/features/requests/presentation/widgets/request_status_seen_mapping.dart';
import 'package:seen_booking/features/requests/presentation/widgets/seen_request_summary_card.dart';
import 'package:seen_booking/features/requests/presentation/widgets/seen_request_ticket.dart';

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
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final s = SeenStrings.of(context);
    final deadline = DateTime.now().add(const Duration(hours: 52, minutes: 30));
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Row(
                children: [
                  Expanded(child: Text('طلباتي', style: type.h1)),
                  SeenRoundIconButton(icon: SeenIcons.search, semanticLabel: 'بحث', onPressed: () {}),
                  const SizedBox(width: SeenSpace.s2),
                  SeenRoundIconButton(icon: SeenIcons.plus, semanticLabel: 'جديد', tonal: true, onPressed: () {}),
                ],
              ),
              const SizedBox(height: SeenSpace.s3),
              Row(
                children: [
                  Expanded(child: SeenStatCard(label: 'كل الطلبات', value: s.numeral(24), dotColor: c.inkMuted)),
                  const SizedBox(width: SeenSpace.s2),
                  Expanded(child: SeenStatCard(label: 'قيد المعالجة', value: s.numeral(8), dotColor: SeenBrand.violet)),
                  const SizedBox(width: SeenSpace.s2),
                  Expanded(child: SeenStatCard(label: 'بانتظار إجراء', value: s.numeral(3), dotColor: SeenBrand.progressWaiting)),
                ],
              ),
              const SizedBox(height: SeenSpace.s3),
              SeenSegmentChips(
                padding: EdgeInsets.zero,
                items: const [
                  SeenSegment(label: 'الكل', count: 24),
                  SeenSegment(label: 'قيد المعالجة', count: 8),
                  SeenSegment(label: 'بانتظار إجراء', count: 3, alert: true),
                  SeenSegment(label: 'مكتمل', count: 12),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
              const SizedBox(height: SeenSpace.s4),
              SeenRequestSummaryCard(
                title: 'دخول مصر',
                subtitle: s.travelerCount(2),
                status: RequestStatus.infoRequired.toSeenRequestStatus(slaDeadline: deadline),
                progress: RequestStatus.infoRequired.progress,
                reference: 'SB-20476',
                dateLabel: '12/11/2026',
                slaDeadline: deadline,
                note: 'مطلوب نسخة أوضح من جواز السفر',
              ),
              const SizedBox(height: SeenSpace.s3),
              SeenRequestSummaryCard(
                title: 'موافقة أمنية · الأردن',
                subtitle: s.travelerCount(1),
                status: RequestStatus.processing.toSeenRequestStatus(),
                progress: RequestStatus.processing.progress,
                reference: 'SB-20481',
                dateLabel: '12/11/2026',
              ),
              const SizedBox(height: SeenSpace.s3),
              SeenRequestSummaryCard(
                title: 'تأشيرة السعودية',
                subtitle: s.travelerCount(3),
                status: RequestStatus.completed.toSeenRequestStatus(),
                progress: RequestStatus.completed.progress,
                reference: 'SB-20470',
                dateLabel: '12/11/2026',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsEmptyPreview extends StatelessWidget {
  const _RequestsEmptyPreview();

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(child: Text('طلباتي', style: type.h1)),
                    SeenRoundIconButton(icon: SeenIcons.plus, semanticLabel: 'جديد', tonal: true, onPressed: () {}),
                  ],
                ),
              ),
              Expanded(
                child: SeenEmptyState(
                  iconAsset: SeenVectors.iconRequests,
                  title: 'لا توجد طلبات بعد',
                  message: 'ابدأ أول طلب لعملائك، وتابع كل مراحله من هنا.',
                  actionLabel: 'اطلب خدمة',
                  onAction: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestDetailPreview extends StatelessWidget {
  const _RequestDetailPreview();

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final s = SeenStrings.of(context);
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  SeenRoundIconButton(icon: SeenIcons.back(context), semanticLabel: 'رجوع', onPressed: () {}),
                  Expanded(child: Text('تتبع الطلب', textAlign: TextAlign.center, style: type.title)),
                  SeenRoundIconButton(icon: SeenIcons.headset, semanticLabel: 'الدعم', onPressed: () {}),
                ],
              ),
              const SizedBox(height: SeenSpace.s4),
              SeenRequestTicket(
                status: SeenRequestStatus.processing,
                statusLabel: s.requestStatus(SeenRequestStatus.processing),
                reference: 'SB-20481',
                title: 'محمد عبدالله الحميري',
                subtitle: 'موافقة أمنية · الأردن',
                feeLabel: 'الرسوم',
                feeValue: SeenFormat.usd(150),
                travelersLabel: 'المسافرون',
                travelersValue: s.numeral(3),
                dateLabel: 'تاريخ الطلب',
                dateValue: '12/11/2026',
              ),
              const SizedBox(height: 18),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: const BorderRadius.all(SeenRadius.r22),
                  border: Border.all(color: c.border),
                  boxShadow: SeenShadows.card,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مراحل الطلب', style: type.title),
                      const SizedBox(height: SeenSpace.s3),
                      SeenStatusStepper(
                        current: 2,
                        steps: [
                          SeenStep(title: s.requestStepTitle(1), meta: '12/11/2026 · 09:14'),
                          SeenStep(title: s.requestStepTitle(2), meta: '12/11/2026 · 11:40'),
                          SeenStep(title: s.requestStepTitle(3), meta: '13/11/2026 · 08:05'),
                          SeenStep(title: s.requestStepTitle(4)),
                          SeenStep(title: s.requestStepTitle(5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
