import '../../../../core/localization/app_language.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/draft_review.dart';

/// Parses `PortalDraftReview` (contract reference). Money arrives as `Decimal`
/// strings and goes straight to integer cents.
abstract final class DraftReviewDto {
  static DraftReview parse(Map<String, dynamic> json, AppLanguage language) {
    final service = json['service'] as Map<String, dynamic>? ?? const {};
    final quote = json['quote'] as Map<String, dynamic>? ?? const {};
    return DraftReview(
      requestId: json['requestId'].toString(),
      status: json['status'] as String? ?? '',
      serviceId: service['id']?.toString() ?? '',
      serviceName: language.pick(ar: service['nameAr'] as String?, en: service['nameEn'] as String?),
      travelers: [
        for (final t in json['travelers'] as List<dynamic>? ?? const [])
          if (t is Map<String, dynamic>)
            ReviewTraveler(
              id: t['id'].toString(),
              index: (t['index'] as num?)?.toInt() ?? 0,
              name: t['name'] as String?,
              nameMasked: t['nameMasked'] == true,
              passportNumber: t['passportNumber'] as String?,
              documentsCount: (t['documentsCount'] as num?)?.toInt() ?? 0,
            ),
      ],
      quote: ReviewQuote(
        currency: quote['currency'] as String?,
        unitPriceCents: _cents(quote['unitPrice']),
        travelerCount: (quote['travelerCount'] as num?)?.toInt() ?? 0,
        totalCents: _cents(quote['total']),
        balanceCents: _cents(quote['balance']),
        availableAfterCents: _cents(quote['availableAfter']),
        creditLimitCents: _cents(quote['creditLimit']),
        fundsSufficient: quote['fundsSufficient'] as bool?,
        holdDeferred: quote['holdDeferred'] == true,
        slaHours: (quote['slaHours'] as num?)?.toInt() ?? 0,
      ),
      canSubmit: json['canSubmit'] == true,
      errors: [for (final e in json['errors'] as List<dynamic>? ?? const []) e.toString()],
      violations: _violations(json['violations']),
    );
  }

  static int? _cents(Object? value) => value == null ? null : MoneyParser.centsFromDecimalString(value.toString());

  /// `violations` is a free JSON value: a list of codes or objects, or an
  /// object keyed by code. Only the codes are kept.
  static List<String> _violations(Object? value) {
    if (value is List) {
      return [
        for (final v in value)
          if (v is Map && v['code'] != null) v['code'].toString() else v.toString(),
      ];
    }
    if (value is Map) return [for (final k in value.keys) k.toString()];
    return const [];
  }
}
