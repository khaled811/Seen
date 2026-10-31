import '../../../../core/localization/app_language.dart';
import '../../domain/entities/missing_document.dart';

/// Parses the information request of a request in "info required" from one
/// answer that carries `portalRequestTracking` (message, deadline, travelers) and
/// `request` (the service's document requirements and what each traveler already
/// has). Both are in the contract; the server does not say which document it
/// wants, so every traveler x requirement is offered, the missing ones first.
abstract final class MissingDocumentDto {
  static MissingDocumentRequest? parse(
    Map<String, dynamic> json,
    AppLanguage language, {
    DateTime Function() clock = DateTime.now,
  }) {
    final tracking = json['portalRequestTracking'] as Map<String, dynamic>?;
    final request = json['request'] as Map<String, dynamic>?;
    final info = tracking?['infoRequest'] as Map<String, dynamic>?;
    if (tracking == null || request == null || info == null) return null;

    final uploadedByTraveler = <String, Set<String>>{
      for (final t in request['travelers'] as List<dynamic>? ?? const [])
        if (t is Map<String, dynamic>)
          t['id'].toString(): {
            for (final d in t['documents'] as List<dynamic>? ?? const [])
              if (d is Map<String, dynamic> && d['documentRequirement'] is Map<String, dynamic>)
                (d['documentRequirement'] as Map<String, dynamic>)['id'].toString(),
          },
    };
    final requirements = [
      for (final d in (request['serviceType'] as Map<String, dynamic>?)?['documents'] as List<dynamic>? ?? const [])
        if (d is Map<String, dynamic>)
          (
            id: d['id'].toString(),
            label: language.pick(ar: d['labelAr'] as String?, en: d['labelEn'] as String?),
          ),
    ];

    final targets = <UploadTarget>[];
    for (final t in tracking['travelers'] as List<dynamic>? ?? const []) {
      if (t is! Map<String, dynamic>) continue;
      final travelerId = t['id'].toString();
      for (final r in requirements) {
        targets.add(UploadTarget(
          travelerId: travelerId,
          requirementId: r.id,
          requirementLabel: r.label,
          travelerLabel: t['name'] as String?,
          alreadyUploaded: uploadedByTraveler[travelerId]?.contains(r.id) ?? false,
        ));
      }
    }
    if (targets.isEmpty) return null;
    // Still missing first (stable otherwise: traveler order, then requirement order).
    final ordered = [
      ...targets.where((t) => !t.alreadyUploaded),
      ...targets.where((t) => t.alreadyUploaded),
    ];

    final deadlineAt = info['deadlineAt'] as String?;
    final remaining = (info['remainingSeconds'] as num?)?.toInt();
    final card = tracking['request'] as Map<String, dynamic>;
    return MissingDocumentRequest(
      requestId: card['id'].toString(),
      referenceId: card['referenceCode'] as String? ?? '',
      reason: info['message'] as String? ?? '',
      targets: ordered,
      deadline: deadlineAt != null
          ? DateTime.parse(deadlineAt)
          : (remaining != null ? clock().add(Duration(seconds: remaining)) : null),
    );
  }
}
