/// Named, single-source-of-truth home for the pricing rule, rather than a
/// bare `*` scattered across the Bloc/UI: `TotalPrice = PerPersonPrice *
/// NumberOfTravelers`.
abstract final class ServicePricing {
  static int totalPriceCents({
    required int perPersonPriceCents,
    required int travelerCount,
  }) =>
      perPersonPriceCents * travelerCount;
}
