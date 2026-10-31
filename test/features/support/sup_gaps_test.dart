// Support gaps (design/gaps SUP): rating (cubit, card, stars), categories (cubit, sheet, search),
// unread (cubit, badge, divider) and the new data sources against the contract.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/core/presentation/widgets/rating_stars.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/utils/arabic_search.dart';
import 'package:seen_booking/features/support/data/datasources/ticket_categories_remote_data_source.dart';
import 'package:seen_booking/features/support/data/datasources/ticket_rating_remote_data_source.dart';
import 'package:seen_booking/features/support/data/datasources/unread_tickets_remote_data_source.dart';
import 'package:seen_booking/features/support/domain/entities/ticket_category_option.dart';
import 'package:seen_booking/features/support/presentation/bloc/ticket_categories_cubit.dart';
import 'package:seen_booking/features/support/presentation/bloc/ticket_rating_cubit.dart';
import 'package:seen_booking/features/support/presentation/bloc/unread_tickets_cubit.dart';
import 'package:seen_booking/features/support/presentation/widgets/support_unread_badge.dart';
import 'package:seen_booking/features/support/presentation/widgets/ticket_category_sheet.dart';
import 'package:seen_booking/features/support/presentation/widgets/ticket_rating_card.dart';
import 'package:seen_booking/core/utils/latin_digits.dart';

import '../../support/rating_fakes.dart';
import '../../support/scripted_graphql_service.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Widget _app(Widget home) => MaterialApp(
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
    );

Future<void> _size(WidgetTester tester, [double h = 900]) async {
  await tester.binding.setSurfaceSize(Size(390, h));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('rating (SUP-06)', () {
    test('pick 1-5 then send once; the chosen stars are kept on a failure and it can be sent again', () async {
      final repo = FakeTicketRatingRepository()..result = const Left(NetworkFailure('offline'));
      final cubit = TicketRatingCubit(repo, ticketId: 't1');
      cubit.select(0);
      cubit.select(6);
      expect(cubit.state.stars, 0);
      await cubit.submit();
      expect(repo.rated, isEmpty, reason: 'nothing chosen yet');

      cubit.select(4);
      await cubit.submit();
      expect((cubit.state.stars, cubit.state.issue), (4, TicketRatingIssue.offline));
      expect(cubit.state.done, isFalse);

      repo.result = const Right(null);
      await cubit.submit();
      expect(cubit.state.done, isTrue);
      expect(repo.rated.map((r) => (r.ticketId, r.rating)), [('t1', 4), ('t1', 4)]);

      cubit.select(2);
      await cubit.submit();
      expect(cubit.state.stars, 4, reason: 'locked once sent');
      expect(repo.rated, hasLength(2));
      await cubit.close();
    });

    test('the server saying it was already rated locks the card instead of showing an error', () async {
      final repo = FakeTicketRatingRepository()..result = const Left(ServerFailure('x', code: 'already_rated'));
      final cubit = TicketRatingCubit(repo, ticketId: 't1')..select(5);
      await cubit.submit();
      expect((cubit.state.done, cubit.state.issue), (true, null));
      await cubit.close();
    });

    test('a ticket that is not resolved is its own issue; a second tap while sending is ignored', () async {
      final repo = FakeTicketRatingRepository()
        ..result = const Left(ServerFailure('x', code: 'ticket_not_resolved'))
        ..hold = Completer<void>();
      final cubit = TicketRatingCubit(repo, ticketId: 't1')..select(3);
      final first = cubit.submit();
      await cubit.submit();
      expect(repo.rated, hasLength(1));
      repo.hold!.complete();
      await first;
      expect(cubit.state.issue, TicketRatingIssue.notResolved);
      await cubit.close();
    });

    testWidgets('the card: stars, the value word, Send; sending locks it and shows the thanks and the "no changes" note', (tester) async {
      await _size(tester);
      final repo = FakeTicketRatingRepository();
      final cubit = TicketRatingCubit(repo, ticketId: 't1');
      addTearDown(cubit.close);
      await tester.pumpWidget(_app(Scaffold(body: BlocProvider.value(value: cubit, child: const TicketRatingCard()))));
      expect(find.text(_l10n.supRateTitle), findsOneWidget);
      expect(find.text(_l10n.supSendRating), findsNothing, reason: 'no button before a star is chosen');

      await tester.tap(find.bySemanticsLabel(_l10n.supStarA11y(4)));
      await tester.pump();
      expect(find.text(_l10n.supStar4), findsOneWidget);
      await tester.tap(find.text(_l10n.supSendRating));
      await tester.pump();
      await tester.pump();
      expect(repo.rated.single.rating, 4);
      expect(find.text(_l10n.supRatedTitle), findsOneWidget);
      expect(find.text(_l10n.supThanks), findsOneWidget);
      expect(find.text(_l10n.supRatedLocked), findsOneWidget);
    });

    testWidgets('a failed send shows the banner and a retry that keeps the stars', (tester) async {
      await _size(tester);
      final repo = FakeTicketRatingRepository()..result = const Left(NetworkFailure('offline'));
      final cubit = TicketRatingCubit(repo, ticketId: 't1');
      addTearDown(cubit.close);
      await tester.pumpWidget(_app(Scaffold(body: BlocProvider.value(value: cubit, child: const TicketRatingCard()))));
      await tester.tap(find.bySemanticsLabel(_l10n.supStarA11y(2)));
      await tester.pump();
      await tester.tap(find.text(_l10n.supSendRating));
      await tester.pump();
      await tester.pump();
      expect(find.text(_l10n.supRateFailed), findsOneWidget);
      expect(find.text(_l10n.commonRetry), findsOneWidget);
      expect(find.text(_l10n.supStar2), findsOneWidget);
    });

    testWidgets('RatingStars: LTR order, readonly and locked do not react, each star has a 44 px tap area', (tester) async {
      await _size(tester);
      final taps = <int>[];
      Widget stars(RatingMode mode) => _app(Scaffold(
            body: Center(
              child: RatingStars(value: 3, mode: mode, onChanged: taps.add, groupLabel: 'g', starLabel: (v) => 's$v'),
            ),
          ));
      await tester.pumpWidget(stars(RatingMode.input));
      final first = tester.getCenter(find.bySemanticsLabel('s1'));
      final fifth = tester.getCenter(find.bySemanticsLabel('s5'));
      expect(first.dx < fifth.dx, isTrue, reason: 'star 1 is on the left even in RTL');
      expect(tester.getSize(find.bySemanticsLabel('s1')).height, greaterThanOrEqualTo(44));
      await tester.tap(find.bySemanticsLabel('s5'));
      expect(taps, [5]);

      for (final mode in [RatingMode.readonly, RatingMode.locked]) {
        await tester.pumpWidget(stars(mode));
        await tester.tap(find.bySemanticsLabel('s5'), warnIfMissed: false);
        expect(taps, [5], reason: mode.name);
      }
    });
  });

  group('categories (SUP-07)', () {
    test('the server\'s catch-all is moved out of the list (Other is added once, last)', () async {
      final cubit = TicketCategoriesCubit(FakeTicketCategoriesRepository());
      await cubit.load();
      expect(cubit.state.options.map((o) => o.code), ['bookings', 'payments', 'account']);
      expect(cubit.state.failed, isFalse);
      await cubit.close();
    });

    test('a failed read is flagged and a retry loads again', () async {
      final repo = FakeTicketCategoriesRepository()..result = const Left(NetworkFailure('offline'));
      final cubit = TicketCategoriesCubit(repo);
      await cubit.load();
      expect(cubit.state.failed, isTrue);
      repo.result = const Right([TicketCategoryOption(code: 'x', name: 'x')]);
      await cubit.load();
      expect(cubit.state.failed, isFalse);
      expect(cubit.state.options, hasLength(1));
      await cubit.close();
    });

    test('Arabic search ignores marks and tatweel and treats the usual letter pairs as one', () {
      expect(ArabicSearch.matches('الحجوزات', 'الْحُجُوزَات'), isTrue);
      expect(ArabicSearch.matches('احمد', 'أحمد'), isTrue);
      expect(ArabicSearch.matches('مدرسة', 'مدرسه'), isTrue);
      expect(ArabicSearch.matches('على', 'علي'), isTrue);
      expect(ArabicSearch.matches('الــحجوزات', 'الحجوزات'), isTrue);
      expect(ArabicSearch.matches('', 'anything'), isTrue);
      expect(ArabicSearch.matches('مدفوعات', 'الحجوزات'), isFalse);
    });

    test('the highlight range is mapped back onto the original text', () {
      // «الْحُجُوزَات»: the marks are skipped when matching, but stay inside the highlighted range.
      const text = 'الْحُجُوزَات والتذاكر';
      final r = ArabicSearch.range('الحجوزات', text)!;
      expect(text.substring(r.start, r.end), 'الْحُجُوزَات');
      expect(ArabicSearch.range('والتذاكر', text)!.end, text.length);
      expect(ArabicSearch.range('zzz', text), isNull);
      expect(ArabicSearch.range('', text), isNull);
    });

    testWidgets('the sheet lists the server\'s categories and Other last; picking returns the row', (tester) async {
      await _size(tester, 1000);
      final cubit = TicketCategoriesCubit(FakeTicketCategoriesRepository());
      addTearDown(cubit.close);
      TicketCategoryOption? picked;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showTicketCategorySheet(context, cubit: cubit),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('الحجوزات والتذاكر'), findsOneWidget);
      expect(find.text(_l10n.supCategoryOther), findsOneWidget);
      final other = tester.getTopLeft(find.text(_l10n.supCategoryOther)).dy;
      for (final name in ['الحجوزات والتذاكر', 'المدفوعات والمحفظة', 'الحساب والصلاحيات']) {
        expect(tester.getTopLeft(find.text(name)).dy < other, isTrue, reason: name);
      }
      await tester.tap(find.text('المدفوعات والمحفظة'));
      await tester.pumpAndSettle();
      expect(picked?.code, 'payments');
    });

    testWidgets('search narrows the rows; no match says so and still offers Other', (tester) async {
      await _size(tester, 1000);
      final cubit = TicketCategoriesCubit(FakeTicketCategoriesRepository());
      addTearDown(cubit.close);
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(onPressed: () => showTicketCategorySheet(context, cubit: cubit), child: const Text('open')),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'مدفوعات');
      await tester.pump();
      expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('المدفوعات')), findsOneWidget);
      expect(find.text('الحجوزات والتذاكر'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.text(_l10n.supCategoryNoResultsTitle), findsOneWidget);
      expect(find.text(_l10n.supCategoryOther), findsOneWidget);
    });

    testWidgets('a failed load shows the error and retry, and Other is still there', (tester) async {
      await _size(tester, 1000);
      final repo = FakeTicketCategoriesRepository()..result = const Left(NetworkFailure('offline'));
      final cubit = TicketCategoriesCubit(repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(onPressed: () => showTicketCategorySheet(context, cubit: cubit), child: const Text('open')),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining(_l10n.supCategoryLoadError), findsOneWidget);
      expect(find.text(_l10n.supCategoryOther), findsOneWidget);
      repo.result = const Right([TicketCategoryOption(code: 'bookings', name: 'الحجوزات')]);
      await tester.tap(find.text(_l10n.commonRetry));
      await tester.pumpAndSettle();
      expect(find.text('الحجوزات'), findsOneWidget);
    });
  });

  group('unread (SUP-08)', () {
    test('the count follows the server, a failed read keeps it, clear empties it', () async {
      final repo = FakeUnreadTicketsRepository()..result = const Right(3);
      final cubit = UnreadTicketsCubit(repo);
      await cubit.refresh();
      expect(cubit.state, 3);
      repo.result = const Left(NetworkFailure('offline'));
      await cubit.refresh();
      expect(cubit.state, 3);
      repo.result = const Right(0);
      await cubit.refresh();
      expect(cubit.state, 0);
      repo.result = const Right(5);
      await cubit.refresh();
      cubit.clear();
      expect(cubit.state, 0);
      await cubit.close();
    });

    testWidgets('the badge shows the count, "9+" above nine, and nothing at zero', (tester) async {
      await _size(tester);
      final repo = FakeUnreadTicketsRepository()..result = const Right(3);
      final cubit = UnreadTicketsCubit(repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(_app(Scaffold(body: Center(child: SupportUnreadBadge(cubit: cubit, child: const SizedBox(width: 44, height: 44))))));
      await tester.pump();
      await tester.pump();
      expect(find.text('٣'), findsOneWidget);
      expect(find.bySemanticsLabel(toArabicIndicDigits(_l10n.supUnreadA11y(3))), findsOneWidget);

      repo.result = const Right(12);
      await cubit.refresh();
      await tester.pump();
      await tester.pump();
      expect(find.text(toArabicIndicDigits(_l10n.supBadgeMax)), findsOneWidget);

      repo.result = const Right(0);
      await cubit.refresh();
      await tester.pump();
      await tester.pump();
      expect(find.text('٣'), findsNothing);
      expect(find.text(toArabicIndicDigits(_l10n.supBadgeMax)), findsNothing);
    });
  });

  group('against the contract', () {
    test('rateTicket sends the ticket and the stars', () async {
      final graphql = ScriptedGraphQLService({
        'RateTicket': {
          'rateTicket': {'ticketId': '7', 'rating': 4, 'ratedAt': '2026-10-21T10:00:00Z'},
        },
      });
      expect((await TicketRatingRemoteDataSource(graphQLService: graphql).rate('7', 4)).isRight(), isTrue);
      expect(graphql.where('RateTicket').single.variables, {'ticketId': '7', 'rating': 4});
    });

    test('ticketCategories keeps the active ones, in sort order, named in the app language', () async {
      final graphql = ScriptedGraphQLService({
        'TicketCategories': {
          'ticketCategories': [
            {'code': 'b', 'nameAr': 'ب', 'nameEn': 'B', 'sortOrder': 2, 'isActive': true},
            {'code': 'gone', 'nameAr': 'ح', 'nameEn': 'Gone', 'sortOrder': 0, 'isActive': false},
            {'code': 'a', 'nameAr': 'أ', 'nameEn': 'A', 'sortOrder': 1, 'isActive': true},
          ],
        },
      });
      final source = TicketCategoriesRemoteDataSource(graphQLService: graphql, language: AppLanguage('en'));
      final list = ((await source.list()) as Right).value as List<TicketCategoryOption>;
      expect(list.map((o) => (o.code, o.name)), [('a', 'A'), ('b', 'B')]);
    });

    test('unreadTicketsCount returns the number', () async {
      final graphql = ScriptedGraphQLService({
        'UnreadTicketsCount': {'unreadTicketsCount': 4},
      });
      expect(await UnreadTicketsRemoteDataSource(graphQLService: graphql).count(), const Right<Failure, int>(4));
    });
  });
}
