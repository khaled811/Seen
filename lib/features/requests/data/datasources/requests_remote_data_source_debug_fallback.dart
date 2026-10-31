import '../../../../core/config/debug_fallbacks.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/cancel_reason.dart';
import '../models/request_detail_dto.dart';
import '../models/request_summary_dto.dart';
import '../models/requests_page_dto.dart';
import '../models/request_timeline_entry_dto.dart';
import '../models/request_traveler_status_dto.dart';
import 'requests_remote_data_source.dart';

/// DEBUG ONLY — decorates a real [RequestsRemoteDataSource] and, only when a
/// real call fails in a debug build, substitutes a canned set of sample
/// requests spanning every status. Same pattern (and the same reasoning) as
/// `DebugFallbackWalletRemoteDataSource`/`DebugFallbackServicesRemoteDataSource`:
/// `kDebugMode` is a compile-time constant, so every fallback branch below
/// is dead-code-eliminated in release.
class DebugFallbackRequestsRemoteDataSource implements RequestsRemoteDataSource {
  DebugFallbackRequestsRemoteDataSource(this._real);

  final RequestsRemoteDataSource _real;

  /// In-memory only — reset on app restart, never touches real persistence.
  /// Keyed by id for O(1) detail/cancel lookups; mutated in place so a
  /// debug-mode cancellation is reflected on the next dashboard fetch.
  final Map<String, RequestDetailDto> _mockRequests = _seedRequests(DateTime.now());

  @override
  Future<Either<Failure, RequestsPageDto>> getRequests({
    required String group,
    String? search,
    int offset = 0,
    int limit = 30,
  }) async {
    final result = await _real.getRequests(group: group, search: search, offset: offset, limit: limit);
    if (!(debugFallbacksEnabled && result.isLeft())) return result;

    final all = _mockRequests.values.map(_toSummary).toList();
    bool inGroup(RequestSummaryDto r, String g) => switch (g) {
          'all' => r.status != 'draft',
          'processing' => const {'submitted', 'pending_agent_approval', 'pending_management_approval', 'under_review', 'processing'}
              .contains(r.status),
          'action_needed' => r.status == 'info_required',
          'completed' => r.status == 'completed',
          'closed' => r.status == 'rejected' || r.status == 'cancelled',
          'draft' => r.status == 'draft',
          _ => false,
        };
    final query = search?.trim().toLowerCase() ?? '';
    final matching = [
      for (final r in all)
        if (inGroup(r, group) &&
            (query.isEmpty ||
                r.referenceId.toLowerCase().contains(query) ||
                r.serviceName.toLowerCase().contains(query) ||
                r.travelerNames.any((n) => n.toLowerCase().contains(query))))
          r,
    ];
    final page = matching.skip(offset).take(limit).toList();
    final needAction = all.where((r) => r.status == 'info_required').toList();
    return Right(
      RequestsPageDto(
        items: page,
        total: matching.length,
        hasMore: offset + page.length < matching.length,
        counts: {
          for (final g in const ['all', 'processing', 'action_needed', 'completed', 'closed'])
            g: all.where((r) => inGroup(r, g)).length,
        },
        attentionCount: needAction.length,
        hasAnyRequests: all.isNotEmpty,
      ),
    );
  }

  @override
  Future<Either<Failure, RequestDetailDto>> getRequestDetail(String requestId) async {
    final result = await _real.getRequestDetail(requestId);
    if (debugFallbacksEnabled && result.isLeft()) {
      final dto = _mockRequests[requestId];
      if (dto == null) {
        return const Left(ServerFailure('Request not found.'));
      }
      return Right(dto);
    }
    return result;
  }

  /// Demo: the first reminder works, a second one within the session is
  /// refused as too soon (to see the "try again later" state).
  final _reminded = <String>{};

  @override
  Future<Either<Failure, void>> remindApprover(String requestId) async {
    final result = await _real.remindApprover(requestId);
    if (!(debugFallbacksEnabled && result.isLeft())) return result;
    if (!_reminded.add(requestId)) {
      return const Left(ServerFailure('Too soon', code: 'RATE_LIMITED', details: {'retryAfterSeconds': 3600}));
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> cancelRequest(String requestId, {CancelReason? reason}) async {
    final result = await _real.cancelRequest(requestId, reason: reason);
    if (debugFallbacksEnabled && result.isLeft()) {
      final dto = _mockRequests[requestId];
      if (dto == null) {
        return const Left(ServerFailure('Request not found.'));
      }
      // Demo: a request already with the authority cannot be withdrawn.
      if (dto.status == 'processing') {
        return const Left(ServerFailure('Not cancellable', code: 'NOT_CANCELLABLE'));
      }
      final cancelled = RequestDetailDto(
        id: dto.id,
        referenceId: dto.referenceId,
        serviceName: dto.serviceName,
        status: 'cancelled',
        totalPriceAmount: dto.totalPriceAmount,
        submittedAt: dto.submittedAt,
        travelers: dto.travelers,
        timeline: [
          ...dto.timeline,
          RequestTimelineEntryDto(
            status: 'cancelled',
            occurredAt: DateTime.now(),
            note: 'Cancelled by agent.',
          ),
        ],
      );
      _mockRequests[requestId] = cancelled;
      return const Right(null);
    }
    return result;
  }

  RequestSummaryDto _toSummary(RequestDetailDto dto) => RequestSummaryDto(
        id: dto.id,
        referenceId: dto.referenceId,
        serviceName: dto.serviceName,
        travelerCount: dto.travelers.length,
        totalPriceAmount: dto.totalPriceAmount,
        status: dto.status,
        submittedAt: dto.submittedAt,
        slaDeadline: dto.slaDeadline,
        travelerNames: [for (final t in dto.travelers) t.name],
        rejectionNote: dto.status == 'info_required'
            ? (dto.timeline.where((t) => t.status == 'info_required').firstOrNull?.note ??
                'صورة الجواز غير واضحة — المسافر 1')
            : null,
      );
}

List<RequestTravelerStatusDto> _travelers(int count) => [
      for (var i = 1; i <= count; i++)
        RequestTravelerStatusDto(name: 'Traveler $i', status: 'approved'),
    ];

Map<String, RequestDetailDto> _seedRequests(DateTime now) {
  final requests = [
    RequestDetailDto(
      id: 'req-1',
      referenceId: 'SB-1001',
      serviceName: 'Egypt National Security Approval',
      status: 'draft',
      totalPriceAmount: '300.00',
      submittedAt: now,
      travelers: _travelers(2),
      timeline: [
        RequestTimelineEntryDto(status: 'draft', occurredAt: now, note: 'Draft created.'),
      ],
    ),
    RequestDetailDto(
      id: 'req-2',
      referenceId: 'SB-1002',
      serviceName: 'Egypt Military Intelligence Approval',
      status: 'submitted',
      totalPriceAmount: '200.00',
      submittedAt: now.subtract(const Duration(days: 2)),
      travelers: _travelers(1),
      timeline: [
        RequestTimelineEntryDto(
          status: 'submitted',
          occurredAt: now.subtract(const Duration(days: 2)),
          note: 'Submitted for review.',
        ),
      ],
    ),
    RequestDetailDto(
      id: 'req-3',
      referenceId: 'SB-1003',
      serviceName: 'Egypt National Security Approval',
      status: 'under_review',
      totalPriceAmount: '450.00',
      submittedAt: now.subtract(const Duration(days: 3)),
      travelers: _travelers(3),
      timeline: [
        RequestTimelineEntryDto(
          status: 'submitted',
          occurredAt: now.subtract(const Duration(days: 3)),
        ),
        RequestTimelineEntryDto(
          status: 'under_review',
          occurredAt: now.subtract(const Duration(days: 1)),
          note: 'Under National Security review.',
        ),
      ],
    ),
    RequestDetailDto(
      id: 'req-4',
      referenceId: 'SB-1004',
      serviceName: 'Egypt Military Intelligence Approval',
      status: 'info_required',
      totalPriceAmount: '400.00',
      submittedAt: now.subtract(const Duration(days: 4)),
      slaDeadline: now.add(const Duration(hours: 30)), // still within the 72h SLA
      travelers: _travelers(2),
      timeline: [
        RequestTimelineEntryDto(
          status: 'submitted',
          occurredAt: now.subtract(const Duration(days: 4)),
        ),
        RequestTimelineEntryDto(
          status: 'info_required',
          occurredAt: now.subtract(const Duration(hours: 42)),
          note: 'Additional passport scan requested.',
        ),
      ],
    ),
    RequestDetailDto(
      id: 'req-5',
      referenceId: 'SB-1005',
      serviceName: 'Egypt National Security Approval',
      status: 'info_required',
      totalPriceAmount: '150.00',
      submittedAt: now.subtract(const Duration(days: 5)),
      slaDeadline: now.subtract(const Duration(hours: 2)), // overdue — urgent demo state
      travelers: _travelers(1),
      timeline: [
        RequestTimelineEntryDto(
          status: 'submitted',
          occurredAt: now.subtract(const Duration(days: 5)),
        ),
        RequestTimelineEntryDto(
          status: 'info_required',
          occurredAt: now.subtract(const Duration(days: 2)),
          note: 'Birth certificate required.',
        ),
      ],
    ),
    RequestDetailDto(
      id: 'req-6',
      referenceId: 'SB-1006',
      serviceName: 'Egypt Military Intelligence Approval',
      status: 'completed',
      totalPriceAmount: '800.00',
      submittedAt: now.subtract(const Duration(days: 10)),
      outputDocumentUrl: 'mock://documents/SB-1006-approval.pdf',
      travelers: const [
        RequestTravelerStatusDto(
          name: 'Traveler 1',
          status: 'approved',
          documents: [
            TravelerDocumentDto(name: 'الموافقة الأمنية.pdf', url: 'mock://documents/SB-1006-approval.pdf', status: 'ISSUED'),
            TravelerDocumentDto(name: 'صورة الجواز.jpg', url: 'mock://documents/SB-1006-passport.jpg', status: 'APPROVED'),
          ],
        ),
        RequestTravelerStatusDto(
          name: 'Traveler 2',
          status: 'approved',
          documents: [
            TravelerDocumentDto(name: 'صورة الجواز.jpg', url: 'mock://documents/SB-1006-passport.jpg', status: 'IN_REVIEW'),
          ],
        ),
        RequestTravelerStatusDto(name: 'Traveler 3', status: 'approved'),
      ],
      timeline: [
        RequestTimelineEntryDto(
          status: 'submitted',
          occurredAt: now.subtract(const Duration(days: 10)),
        ),
        RequestTimelineEntryDto(
          status: 'processing',
          occurredAt: now.subtract(const Duration(days: 6)),
        ),
        RequestTimelineEntryDto(
          status: 'completed',
          occurredAt: now.subtract(const Duration(days: 2)),
          note: 'Approval document issued.',
        ),
      ],
    ),
    RequestDetailDto(
      id: 'req-7',
      referenceId: 'SB-1007',
      serviceName: 'Egypt National Security Approval',
      status: 'rejected',
      totalPriceAmount: '150.00',
      submittedAt: now.subtract(const Duration(days: 8)),
      travelers: _travelers(1),
      timeline: [
        RequestTimelineEntryDto(
          status: 'submitted',
          occurredAt: now.subtract(const Duration(days: 8)),
        ),
        RequestTimelineEntryDto(
          status: 'rejected',
          occurredAt: now.subtract(const Duration(days: 5)),
          note: 'Passport expiry did not meet the 6-month rule.',
        ),
      ],
      rejectionReason: 'صورة الجواز غير مطابقة للبيانات المدخلة (اختلاف في تاريخ الميلاد). صحّح البيانات وأعد التقديم.',
      refundedAmount: '150.00',
    ),
    RequestDetailDto(
      id: 'req-8',
      referenceId: 'SB-1008',
      serviceName: 'Egypt Military Intelligence Approval',
      status: 'cancelled',
      totalPriceAmount: '400.00',
      submittedAt: now.subtract(const Duration(days: 6)),
      travelers: _travelers(2),
      timeline: [
        RequestTimelineEntryDto(
          status: 'submitted',
          occurredAt: now.subtract(const Duration(days: 6)),
        ),
        RequestTimelineEntryDto(
          status: 'cancelled',
          occurredAt: now.subtract(const Duration(days: 5)),
          note: 'Cancelled by agent.',
        ),
      ],
      cancellation: RequestCancellationDto(
        cancelledBy: 'وليد ناصر (موظف)',
        cancelledAt: now.subtract(const Duration(days: 5)),
        reason: 'العميل غيّر موعد السفر',
      ),
      refundedAmount: '400.00',
    ),
    RequestDetailDto(
      id: 'req-12',
      referenceId: 'SB-1012',
      serviceName: 'دخول مصر',
      status: 'processing',
      totalPriceAmount: '60.00',
      submittedAt: now.subtract(const Duration(days: 3)),
      travelers: _travelers(1),
      timeline: [
        RequestTimelineEntryDto(status: 'submitted', occurredAt: now.subtract(const Duration(days: 3))),
        RequestTimelineEntryDto(status: 'processing', occurredAt: now.subtract(const Duration(days: 1))),
      ],
    ),
    RequestDetailDto(
      id: 'req-9',
      referenceId: 'SB-1009',
      serviceName: 'حجز طيران',
      status: 'pending_agent_approval',
      totalPriceAmount: '1240.00',
      submittedAt: now.subtract(const Duration(hours: 1)),
      travelers: _travelers(4),
      timeline: [RequestTimelineEntryDto(status: 'submitted', occurredAt: now.subtract(const Duration(hours: 1)))],
      approval: const RequestApprovalDto(
        kind: 'MASTER_AGENT',
        approverName: 'مكتب الريان',
        typicalWaitMinutes: 120,
      ),
    ),
    RequestDetailDto(
      id: 'req-10',
      referenceId: 'SB-1010',
      serviceName: 'حجز طيران',
      status: 'pending_management_approval',
      totalPriceAmount: '2400.00',
      submittedAt: now.subtract(const Duration(hours: 5)),
      travelers: _travelers(4),
      timeline: [RequestTimelineEntryDto(status: 'submitted', occurredAt: now.subtract(const Duration(hours: 5)))],
      approval: const RequestApprovalDto(
        kind: 'MANAGEMENT',
        approverName: 'إدارة جُباري',
        typicalWaitMinutes: 1440,
        thresholdAmount: '2000.00',
      ),
    ),
    RequestDetailDto(
      id: 'req-11',
      referenceId: 'SB-1011',
      serviceName: 'دخول مصر',
      status: 'cancelled',
      totalPriceAmount: '60.00',
      submittedAt: now.subtract(const Duration(days: 7)),
      travelers: _travelers(1),
      timeline: [
        RequestTimelineEntryDto(status: 'submitted', occurredAt: now.subtract(const Duration(days: 7))),
        RequestTimelineEntryDto(status: 'cancelled', occurredAt: now.subtract(const Duration(days: 4))),
      ],
      cancellation: RequestCancellationDto(
        cancelledAt: now.subtract(const Duration(days: 4)),
        code: 'DEADLINE_EXPIRED',
      ),
      refundedAmount: '60.00',
    ),
  ];
  return {for (final r in requests) r.id: r};
}
