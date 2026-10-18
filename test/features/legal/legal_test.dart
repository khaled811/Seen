// AUTH-09 terms of use / AUTH-10 privacy policy. Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/legal/data/datasources/legal_data_sources.dart';
import 'package:seen_booking/features/legal/data/repositories/legal_repository_impl.dart';
import 'package:seen_booking/features/legal/domain/entities/legal_document.dart';
import 'package:seen_booking/features/legal/domain/repositories/legal_repository.dart';
import 'package:seen_booking/features/legal/presentation/bloc/legal_cubit.dart';
import 'package:seen_booking/features/legal/presentation/screens/legal_document_screen.dart';

LegalDocument _doc(LegalKind kind, LegalLanguage lang, {String heading = 'عنوان'}) => LegalDocument(
      kind: kind,
      language: lang,
      updatedAt: DateTime(2026, 10, 1),
      sections: [LegalSection(heading: heading, body: 'نص $heading')],
    );

class _Remote implements LegalRemoteDataSource {
  Either<Failure, LegalDocument>? forced;
  final calls = <String>[];

  @override
  Future<Either<Failure, LegalDocument>> fetch(LegalKind kind, LegalLanguage language) async {
    calls.add('${kind.name}:${language.name}');
    return forced ?? Right(_doc(kind, language, heading: language == LegalLanguage.ar ? 'نطاق الخدمة' : 'Scope'));
  }
}

class _Cache implements LegalCache {
  final map = <String, LegalDocument>{};

  @override
  Future<LegalDocument?> read(LegalKind kind, LegalLanguage language) async => map['${kind.name}:${language.name}'];

  @override
  Future<void> write(LegalDocument d) async => map['${d.kind.name}:${d.language.name}'] = d;
}

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

LegalCubit _cubit(_Remote remote, _Cache cache, LegalKind kind, LegalLanguage lang) => LegalCubit(
      kind: kind,
      initial: lang,
      get: GetLegalDocumentUseCase(LegalRepositoryImpl(remote: remote, cache: cache)),
    );

void main() {
  group('repository', () {
    test('a fresh text is saved; offline serves the saved copy; neither fails', () async {
      final remote = _Remote();
      final cache = _Cache();
      final repo = LegalRepositoryImpl(remote: remote, cache: cache);
      final fresh = (await repo.get(LegalKind.terms, LegalLanguage.ar)).toNullable()!;
      expect(fresh.fromCache, isFalse);
      expect(cache.map.containsKey('terms:ar'), isTrue);

      remote.forced = const Left(NetworkFailure('offline'));
      final offline = (await repo.get(LegalKind.terms, LegalLanguage.ar)).toNullable()!;
      expect(offline.fromCache, isTrue);

      final none = await repo.get(LegalKind.privacy, LegalLanguage.ar);
      expect(none.isLeft(), isTrue);
    });
  });

  group('cubit', () {
    test('switching language reloads in that language; the same language is a no-op', () async {
      final remote = _Remote();
      final cubit = _cubit(remote, _Cache(), LegalKind.terms, LegalLanguage.ar);
      await cubit.load();
      expect(cubit.state.result!.document.language, LegalLanguage.ar);
      await cubit.setLanguage(LegalLanguage.ar);
      expect(remote.calls, ['terms:ar']);
      await cubit.setLanguage(LegalLanguage.en);
      expect(cubit.state.language, LegalLanguage.en);
      expect(cubit.state.result!.document.language, LegalLanguage.en);
      await cubit.close();
    });

    test('a failure with no saved copy can be retried', () async {
      final remote = _Remote()..forced = const Left(NetworkFailure('offline'));
      final cubit = _cubit(remote, _Cache(), LegalKind.privacy, LegalLanguage.ar);
      await cubit.load();
      expect(cubit.state.status, LegalStatus.failure);
      remote.forced = null;
      await cubit.load();
      expect(cubit.state.status, LegalStatus.loaded);
      await cubit.close();
    });
  });

  group('screen', () {
    testWidgets('terms: title, last update, sections; the English switch loads the English text LTR', (tester) async {
      final remote = _Remote();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(LegalDocumentScreen(
        kind: LegalKind.terms,
        createCubit: (l) => _cubit(remote, _Cache(), LegalKind.terms, l),
      )));
      await tester.pump();
      await tester.pump();
      expect(find.text('الشروط والأحكام'), findsOneWidget);
      expect(find.textContaining('آخر تحديث'), findsOneWidget);
      expect(find.text('نطاق الخدمة'), findsOneWidget);
      expect(find.textContaining('أنت غير متصل'), findsNothing);

      await tester.tap(find.text('English'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Scope'), findsOneWidget);
      final dir = Directionality.of(tester.element(find.text('Scope')));
      expect(dir, TextDirection.ltr);
    });

    testWidgets('privacy offline: shows the saved copy with the offline note', (tester) async {
      final remote = _Remote()..forced = const Left(NetworkFailure('offline'));
      final cache = _Cache()..map['privacy:ar'] = _doc(LegalKind.privacy, LegalLanguage.ar, heading: 'ما الذي نجمعه');
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(LegalDocumentScreen(
        kind: LegalKind.privacy,
        createCubit: (l) => _cubit(remote, cache, LegalKind.privacy, l),
      )));
      await tester.pump();
      await tester.pump();
      expect(find.text('سياسة الخصوصية'), findsOneWidget);
      expect(find.text('ما الذي نجمعه'), findsOneWidget);
      expect(find.text('أنت غير متصل. نعرض النسخة المحفوظة.'), findsOneWidget);
    });

    testWidgets('no text and no saved copy: a message and a working retry', (tester) async {
      final remote = _Remote()..forced = const Left(NetworkFailure('offline'));
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(LegalDocumentScreen(
        kind: LegalKind.terms,
        createCubit: (l) => _cubit(remote, _Cache(), LegalKind.terms, l),
      )));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('تعذّر تحميل النص'), findsOneWidget);
      remote.forced = null;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();
      await tester.pump();
      expect(find.text('نطاق الخدمة'), findsOneWidget);
    });
  });
}
