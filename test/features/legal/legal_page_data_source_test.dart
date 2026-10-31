// The legal texts against the contract: `legalPage(kind)` validated against the
// reference, and the plain body turned into sections (never HTML).

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/features/legal/data/datasources/legal_data_sources.dart';
import 'package:seen_booking/features/legal/domain/entities/legal_document.dart';

import '../../support/scripted_graphql_service.dart';

Map<String, Object?> _page({String bodyAr = 'نص', String bodyEn = '## Scope\n\nWe help.\n\n- one\n- two\n\n## Data\nYours.'}) => {
      'legalPage': {
        'kind': 'terms',
        'titleAr': 'الشروط',
        'titleEn': 'Terms',
        'bodyAr': bodyAr,
        'bodyEn': bodyEn,
        'version': 3,
        'updatedAt': '2026-10-01T09:00:00+00:00',
      },
    };

void main() {
  group('parseLegalBody', () {
    test('headings, paragraphs and bullets', () {
      final sections = parseLegalBody('## Scope\n\nWe help.\nSecond line.\n\n- one\n- two\n\n## Data\nYours.');
      expect(sections.map((s) => s.heading), ['Scope', 'Data']);
      expect(sections[0].body, 'We help.\nSecond line.\n\n• one\n• two');
      expect(sections[1].body, 'Yours.');
    });

    test('text before any heading is a section without one', () {
      final sections = parseLegalBody('Intro\n\n## A\nBody');
      expect(sections.first.heading, '');
      expect(sections.first.body, 'Intro');
      expect(sections.length, 2);
    });

    test('markup is just text', () {
      final sections = parseLegalBody('## <b>x</b>\n<script>alert(1)</script>');
      expect(sections.single.heading, '<b>x</b>');
      expect(sections.single.body, '<script>alert(1)</script>');
    });

    test('empty and windows line endings', () {
      expect(parseLegalBody(''), isEmpty);
      expect(parseLegalBody('## A\r\nB\r\n\r\nC').single.body, 'B\n\nC');
    });
  });

  group('LegalRemoteDataSourceImpl', () {
    test('asks for the page by kind and picks the body in the language', () async {
      final graphql = ScriptedGraphQLService({'LegalPage': _page()});
      final source = LegalRemoteDataSourceImpl(graphQLService: graphql);
      final en = ((await source.fetch(LegalKind.terms, LegalLanguage.en)) as Right<dynamic, LegalDocument>).value;
      expect(en.sections.map((s) => s.heading), ['Scope', 'Data']);
      expect(en.updatedAt.toUtc(), DateTime.utc(2026, 10, 1, 9));
      final ar = ((await source.fetch(LegalKind.privacy, LegalLanguage.ar)) as Right<dynamic, LegalDocument>).value;
      expect(ar.sections.single.body, 'نص');
      expect(graphql.where('LegalPage').map((o) => o.variables['kind']), ['terms', 'privacy']);
    });

    test('an empty body in the language falls back to the other one', () async {
      final graphql = ScriptedGraphQLService({'LegalPage': _page(bodyAr: '   ')});
      final source = LegalRemoteDataSourceImpl(graphQLService: graphql);
      final ar = ((await source.fetch(LegalKind.terms, LegalLanguage.ar)) as Right<dynamic, LegalDocument>).value;
      expect(ar.sections.first.heading, 'Scope');
    });
  });
}
