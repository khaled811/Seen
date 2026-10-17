// Help centre (Figma SUP-04). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/support/domain/entities/help_article.dart';
import 'package:seen_booking/features/support/presentation/screens/help_center_screen.dart';

const _all = [
  HelpArticle(id: 'a', topic: HelpTopic.wallet, question: 'متى يُخصم المبلغ؟', answer: 'عند الإنجاز.'),
  HelpArticle(id: 'b', topic: HelpTopic.requests, question: 'كيف أرفع مستندًا؟', answer: 'من صفحة الطلب.'),
  HelpArticle(id: 'c', topic: HelpTopic.account, question: 'كيف أضيف وكيلًا؟', answer: 'من تبويب الوكلاء.'),
];

void main() {
  group('filterHelpArticles', () {
    test('no query and no topic keeps everything', () {
      expect(filterHelpArticles(_all).length, 3);
    });

    test('matches the question or the answer, ignoring spaces', () {
      expect(filterHelpArticles(_all, query: '  وكيلًا ').map((a) => a.id), ['c']);
      expect(filterHelpArticles(_all, query: 'الإنجاز').map((a) => a.id), ['a']);
      expect(filterHelpArticles(_all, query: 'zzz'), isEmpty);
    });

    test('a topic narrows it, and combines with the query', () {
      expect(filterHelpArticles(_all, topic: HelpTopic.requests).map((a) => a.id), ['b']);
      expect(filterHelpArticles(_all, topic: HelpTopic.wallet, query: 'مستندًا'), isEmpty);
    });
  });

  group('HelpCenterScreen', () {
    var contacted = 0;

    Future<void> open(WidgetTester tester) async {
      contacted = 0;
      await tester.binding.setSurfaceSize(const Size(390, 1000));
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
        home: HelpCenterScreen(onContactSupport: (_) => contacted++),
      ));
      await tester.pump();
    }

    testWidgets('shows the search, the topics and the questions', (tester) async {
      await open(tester);
      expect(find.text('مركز المساعدة'), findsOneWidget);
      expect(find.text('المحفظة'), findsOneWidget);
      expect(find.text('الطلبات'), findsOneWidget);
      expect(find.text('الحساب'), findsOneWidget);
      expect(find.text('متى يُخصم مبلغ الطلب من رصيدي؟'), findsOneWidget);
      expect(find.text('كيف أرفع مستندًا ناقصًا؟'), findsOneWidget);
      expect(find.text('ما قاعدة صلاحية الجواز ٦ أشهر؟'), findsOneWidget);
      expect(find.text('كيف أضيف وكيلًا فرعيًا؟'), findsOneWidget);
    });

    testWidgets('a question opens to its answer and closes again', (tester) async {
      await open(tester);
      expect(find.textContaining('يُحجز مبلغه من رصيدك المتاح'), findsNothing);
      await tester.tap(find.text('متى يُخصم مبلغ الطلب من رصيدي؟'));
      await tester.pump();
      expect(find.textContaining('يُحجز مبلغه من رصيدك المتاح'), findsOneWidget);
      // opening another one closes the first
      await tester.tap(find.text('كيف أضيف وكيلًا فرعيًا؟'));
      await tester.pump();
      expect(find.textContaining('يُحجز مبلغه من رصيدك المتاح'), findsNothing);
      expect(find.textContaining('حدّد سقفه الائتماني'), findsOneWidget);
      await tester.tap(find.text('كيف أضيف وكيلًا فرعيًا؟'));
      await tester.pump();
      expect(find.textContaining('حدّد سقفه الائتماني'), findsNothing);
    });

    testWidgets('typing narrows the list; a topic narrows it too and toggles off', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'الجواز');
      await tester.pump();
      expect(find.text('ما قاعدة صلاحية الجواز ٦ أشهر؟'), findsOneWidget);
      expect(find.text('كيف أضيف وكيلًا فرعيًا؟'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.text('الحساب'));
      await tester.pump();
      expect(find.text('كيف أضيف وكيلًا فرعيًا؟'), findsOneWidget);
      expect(find.text('متى يُخصم مبلغ الطلب من رصيدي؟'), findsNothing);
      await tester.tap(find.text('الحساب'));
      await tester.pump();
      expect(find.text('متى يُخصم مبلغ الطلب من رصيدي؟'), findsOneWidget);
    });

    testWidgets('no match says so, and the contact link leads to support', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'لا شيء يطابق هذا');
      await tester.pump();
      expect(find.text('لا توجد نتائج مطابقة.'), findsOneWidget);
      await tester.tap(find.text('لا نتائج؟ تواصل مع الدعم مباشرة'));
      expect(contacted, 1);
    });
  });
}
