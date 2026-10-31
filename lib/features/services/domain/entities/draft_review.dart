import 'package:equatable/equatable.dart';

/// The fee and wallet position of a draft, as the server quotes it
/// (`PortalReviewQuote`). Money is integer cents; a figure the server leaves
/// out stays null (the screen hides it rather than guessing).
class ReviewQuote extends Equatable {
  const ReviewQuote({
    required this.travelerCount,
    required this.holdDeferred,
    required this.slaHours,
    this.currency,
    this.unitPriceCents,
    this.totalCents,
    this.balanceCents,
    this.availableAfterCents,
    this.creditLimitCents,
    this.fundsSufficient,
  });

  final String? currency;
  final int? unitPriceCents;
  final int travelerCount;
  final int? totalCents;
  final int? balanceCents;
  final int? availableAfterCents;
  final int? creditLimitCents;

  /// Null when the server could not say.
  final bool? fundsSufficient;

  /// True when no money moves at submit (the service waits for approval and the
  /// hold happens then, contract section 9).
  final bool holdDeferred;
  final int slaHours;

  @override
  List<Object?> get props => [
        currency,
        unitPriceCents,
        travelerCount,
        totalCents,
        balanceCents,
        availableAfterCents,
        creditLimitCents,
        fundsSufficient,
        holdDeferred,
        slaHours,
      ];
}

/// One traveler line of the review (the name may come masked).
class ReviewTraveler extends Equatable {
  const ReviewTraveler({
    required this.id,
    required this.index,
    required this.nameMasked,
    required this.documentsCount,
    this.name,
    this.passportNumber,
  });

  final String id;
  final int index;
  final String? name;
  final bool nameMasked;
  final String? passportNumber;
  final int documentsCount;

  @override
  List<Object?> get props => [id, index, name, nameMasked, passportNumber, documentsCount];
}

/// `portalDraftReview`: what the person is about to submit, the quote, and
/// whether the server will take it ([canSubmit]).
class DraftReview extends Equatable {
  const DraftReview({
    required this.requestId,
    required this.status,
    required this.serviceId,
    required this.serviceName,
    required this.travelers,
    required this.quote,
    required this.canSubmit,
    this.errors = const [],
    this.violations = const [],
  });

  final String requestId;
  final String status;
  final String serviceId;
  final String serviceName;
  final List<ReviewTraveler> travelers;
  final ReviewQuote quote;
  final bool canSubmit;

  /// Machine codes of what blocks the submit; shown only as a generic message
  /// (the server's own vocabulary is not localized by the app).
  final List<String> errors;
  final List<String> violations;

  /// Whether the server names a reason it will not take the request yet.
  bool get hasBlockers => errors.isNotEmpty || violations.isNotEmpty;

  @override
  List<Object?> get props => [requestId, status, serviceId, serviceName, travelers, quote, canSubmit, errors, violations];
}
