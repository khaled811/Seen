import '../../../../core/constants/enums.dart';
import '../../../../core/localization/app_language.dart';
import '../../domain/entities/request_detail.dart';
import 'request_detail_dto.dart';
import 'request_summary_dto.dart';
import 'request_timeline_entry_dto.dart';
import 'request_traveler_status_dto.dart';
import 'requests_page_dto.dart';

/// Maps the wire shapes of `portalRequests` and `portalRequestTracking`
/// (`docs/api/mobile-api-reference.md`: `PortalRequestList`, `PortalRequestCard`,
/// `PortalRequestTracking`) to the DTOs the repository already understands.
///
/// Amounts stay `Decimal` strings, unknown statuses stay unknown (never a
/// crash), and bilingual names are picked with the app language.
abstract final class PortalRequestsMapping {
  /// `PortalRequestCard` -> list row.
  static RequestSummaryDto card(Map<String, dynamic> json, AppLanguage language) {
    final status = json['status'] as String?;
    return RequestSummaryDto(
      id: json['id'] as String,
      referenceId: json['referenceCode'] as String? ?? '',
      serviceName: language.pick(ar: json['serviceNameAr'] as String?, en: json['serviceNameEn'] as String?),
      travelerCount: json['travelerCount'] as int? ?? 0,
      totalPriceAmount: json['amount'] as String? ?? '0.00',
      status: status,
      submittedAt: DateTime.parse(json['createdAt'] as String),
      // The deadline matters (and is shown) while the agency owes information.
      slaDeadline: status == RequestStatus.infoRequired.value && json['deadlineAt'] != null
          ? DateTime.parse(json['deadlineAt'] as String)
          : null,
      travelerNames: [for (final n in json['travelerNames'] as List<dynamic>? ?? const []) n as String],
    );
  }

  /// `PortalRequestList`.
  static RequestsPageDto page(Map<String, dynamic> json, AppLanguage language) {
    final attention = json['attention'] as Map<String, dynamic>?;
    return RequestsPageDto(
      items: [for (final c in json['items'] as List<dynamic>? ?? const []) card(c as Map<String, dynamic>, language)],
      total: json['total'] as int? ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
      counts: {
        for (final f in json['filters'] as List<dynamic>? ?? const [])
          (f as Map<String, dynamic>)['key'] as String: f['count'] as int? ?? 0,
      },
      attentionCount: attention?['count'] as int? ?? 0,
      attentionSoonestSeconds: attention?['soonestRemainingSeconds'] as int?,
      hasAnyRequests: json['hasAnyRequests'] as bool? ?? true,
      canCreate: json['canCreate'] as bool? ?? true,
    );
  }

  /// `PortalRequestTracking` -> the request detail.
  static RequestDetailDto tracking(Map<String, dynamic> json, AppLanguage language) {
    final request = json['request'] as Map<String, dynamic>;
    final status = request['status'] as String?;
    final infoRequest = json['infoRequest'] as Map<String, dynamic>?;
    final terminal = json['terminal'] as Map<String, dynamic>?;
    final terminalKind = terminal?['kind'] as String?;
    final actions = json['actions'] as Map<String, dynamic>?;

    DateTime? time(Object? v) => v is String ? DateTime.parse(v) : null;

    // The waiting-for-information deadline: the info request's own, else the card's.
    final deadline = time(infoRequest?['deadlineAt']) ??
        (status == RequestStatus.infoRequired.value ? time(request['deadlineAt']) : null);

    return RequestDetailDto(
      id: request['id'] as String,
      referenceId: request['referenceCode'] as String? ?? '',
      serviceName: language.pick(ar: request['serviceNameAr'] as String?, en: request['serviceNameEn'] as String?),
      status: status,
      totalPriceAmount: (json['feeTotal'] as String?) ?? (request['amount'] as String?) ?? '0.00',
      submittedAt: DateTime.parse(json['filedAt'] as String),
      slaDeadline: deadline,
      rejectionReason: terminalKind == RequestStatus.rejected.value ? (terminal?['reason'] as String?) : null,
      cancellation: terminalKind == RequestStatus.cancelled.value
          ? RequestCancellationDto(
              cancelledAt: time(terminal?['at']),
              reason: terminal?['reason'] as String?,
            )
          : null,
      infoRequestMessage: infoRequest?['message'] as String?,
      actions: actions == null
          ? null
          : RequestActions(
              canCancel: actions['canCancel'] as bool? ?? false,
              cancelReleasesFunds: actions['cancelReleasesFunds'] as bool? ?? false,
              canAddDocuments: actions['canAddDocuments'] as bool? ?? false,
              canViewDocuments: actions['canViewDocuments'] as bool? ?? false,
              canDownloadResult: actions['canDownloadResult'] as bool? ?? false,
              canDecideApproval: actions['canDecideApproval'] as bool? ?? false,
              canContactSupport: actions['canContactSupport'] as bool? ?? false,
            ),
      outputs: [
        for (final o in json['outputs'] as List<dynamic>? ?? const [])
          RequestOutput(
            fileId: (o as Map<String, dynamic>)['fileId'] as String,
            fileName: o['fileName'] as String? ?? '',
            contentType: o['contentType'] as String? ?? '',
            sizeBytes: o['sizeBytes'] as int? ?? 0,
          ),
      ],
      travelers: [
        for (final t in json['travelers'] as List<dynamic>? ?? const [])
          RequestTravelerStatusDto(
            name: (t as Map<String, dynamic>)['name'] as String? ?? '',
            status: t['status'] as String?,
          ),
      ],
      // Only the steps already reached carry a time; a step whose key is not a
      // status the app knows is left out rather than guessed.
      timeline: [
        for (final s in json['timeline'] as List<dynamic>? ?? const [])
          if ((s as Map<String, dynamic>)['at'] != null &&
              RequestStatus.fromValue(s['key'] as String?) != RequestStatus.unknown)
            RequestTimelineEntryDto(status: s['key'] as String?, occurredAt: DateTime.parse(s['at'] as String)),
      ],
    );
  }
}
