import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/repositories/legal_repository.dart';

String _kind(LegalKind k) => k == LegalKind.terms ? 'terms' : 'privacy';
String _lang(LegalLanguage l) => l == LegalLanguage.ar ? 'ar' : 'en';

Map<String, Object?> _toJson(LegalDocument d) => {
      'updatedAt': d.updatedAt.toIso8601String(),
      'sections': [
        for (final s in d.sections) {'heading': s.heading, 'body': s.body},
      ],
    };

LegalDocument? _fromJson(LegalKind kind, LegalLanguage lang, Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final at = DateTime.tryParse(raw['updatedAt'] as String? ?? '');
  final sections = raw['sections'];
  if (at == null || sections is! List) {
    return null;
  }
  return LegalDocument(
    kind: kind,
    language: lang,
    updatedAt: at.toLocal(),
    sections: [
      for (final s in sections.whereType<Map>())
        LegalSection(heading: s['heading'] as String? ?? '', body: s['body'] as String? ?? ''),
    ],
  );
}

/// Raw GraphQL access to the legal texts.
///
/// TODO(backend-contract): placeholder schema; see docs/BACKEND_MIGRATION_GAPS.md section 37.
abstract interface class LegalRemoteDataSource {
  Future<Either<Failure, LegalDocument>> fetch(LegalKind kind, LegalLanguage language);
}

class LegalRemoteDataSourceImpl implements LegalRemoteDataSource {
  LegalRemoteDataSourceImpl({required GraphQLService graphQLService}) : _graphQL = graphQLService;

  final GraphQLService _graphQL;

  static final _document = gql(r'''
    query LegalDocument($kind: String!, $language: String!) {
      legalDocument(kind: $kind, language: $language) {
        updatedAt
        sections { heading body }
      }
    }
  ''');

  @override
  Future<Either<Failure, LegalDocument>> fetch(LegalKind kind, LegalLanguage language) {
    return _graphQL.query<LegalDocument>(
      QueryOptions<LegalDocument>(
        document: _document,
        variables: {'kind': _kind(kind), 'language': _lang(language)},
        fetchPolicy: FetchPolicy.networkOnly,
        parserFn: (json) =>
            _fromJson(kind, language, json['legalDocument']) ?? (throw const FormatException('legalDocument')),
      ),
    );
  }
}

/// DEBUG ONLY: when the real call fails in a debug build, answers with the sample text from
/// the Figma frames so the screens can be looked at without a backend. Release builds drop
/// the branch (`kDebugMode` is a compile-time constant).
class DebugFallbackLegalRemoteDataSource implements LegalRemoteDataSource {
  DebugFallbackLegalRemoteDataSource(this._real);

  final LegalRemoteDataSource _real;

  @override
  Future<Either<Failure, LegalDocument>> fetch(LegalKind kind, LegalLanguage language) async {
    final result = await _real.fetch(kind, language);
    if (kDebugMode && result.isLeft()) {
      return Right(_sample(kind, language));
    }
    return result;
  }

  static LegalDocument _sample(LegalKind kind, LegalLanguage lang) {
    final ar = lang == LegalLanguage.ar;
    final at = DateTime(2026, 10, 1);
    if (kind == LegalKind.terms) {
      return LegalDocument(kind: kind, language: lang, updatedAt: at, sections: [
        LegalSection(
          heading: ar ? '١. نطاق الخدمة' : '1. Scope of the service',
          body: ar
              ? 'تقدّم سين Business لوكالات السفر المرخّصة خدمات طلب التأشيرات والموافقات والحجوزات نيابة عن عملائها.'
              : 'Seen Business provides licensed travel agencies with visa, approval and booking request services on behalf of their customers.',
        ),
        LegalSection(
          heading: ar ? '٢. مسؤولية البيانات' : '2. Responsibility for data',
          body: ar
              ? 'تتحمّل الوكالة صحة بيانات المسافرين والمستندات المرفوعة، وتتحمّل تبعات أي بيانات غير صحيحة.'
              : 'The agency is responsible for the accuracy of traveler data and uploaded documents, and for the consequences of any incorrect data.',
        ),
        LegalSection(
          heading: ar ? '٣. الرسوم والمحفظة' : '3. Fees and the wallet',
          body: ar
              ? 'تُحجز رسوم الطلب عند الإرسال وتُخصم عند الإنجاز، وتُعاد عند الرفض أو الإلغاء وفق سياسة كل خدمة.'
              : 'Request fees are held when submitted and charged on completion, and returned on rejection or cancellation according to each service\'s policy.',
        ),
      ]);
    }
    return LegalDocument(kind: kind, language: lang, updatedAt: at, sections: [
      LegalSection(
        heading: ar ? 'ما الذي نجمعه' : 'What we collect',
        body: ar
            ? 'بيانات الوكالة والمستخدمين، وبيانات المسافرين ومستنداتهم اللازمة لتنفيذ الطلبات.'
            : 'Agency and user data, and the travelers\' data and documents needed to carry out requests.',
      ),
      LegalSection(
        heading: ar ? 'كيف نستخدمها' : 'How we use it',
        body: ar
            ? 'لتنفيذ الطلبات لدى الجهات المختصة، وإرسال الإشعارات، وتحسين الخدمة.'
            : 'To carry out requests with the competent authorities, send notifications and improve the service.',
      ),
      LegalSection(
        heading: ar ? 'مدة الاحتفاظ' : 'Retention',
        body: ar
            ? 'نحتفظ بمستندات الطلبات للمدة التي تشترطها الجهات ثم نحذفها.'
            : 'We keep request documents for as long as the authorities require, then delete them.',
      ),
    ]);
  }
}

/// [LegalCache] over `shared_preferences` (the texts are public, not secrets).
class SharedPreferencesLegalCache implements LegalCache {
  const SharedPreferencesLegalCache();

  String _key(LegalKind k, LegalLanguage l) => 'legal_${_kind(k)}_${_lang(l)}';

  @override
  Future<LegalDocument?> read(LegalKind kind, LegalLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(kind, language));
      return raw == null ? null : _fromJson(kind, language, jsonDecode(raw));
    } catch (_) {
      return null; // a corrupt or unavailable cache is just "no copy"
    }
  }

  @override
  Future<void> write(LegalDocument document) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(document.kind, document.language), jsonEncode(_toJson(document)));
    } catch (_) {
      // Not saving only means no offline copy next time.
    }
  }
}
