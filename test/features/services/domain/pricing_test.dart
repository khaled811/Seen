import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/services/domain/pricing.dart';

void main() {
  group('ServicePricing.totalPriceCents', () {
    test('multiplies per-person price by traveler count', () {
      expect(
        ServicePricing.totalPriceCents(perPersonPriceCents: 15000, travelerCount: 3),
        45000,
      );
    });

    test('returns 0 for zero travelers', () {
      expect(
        ServicePricing.totalPriceCents(perPersonPriceCents: 15000, travelerCount: 0),
        0,
      );
    });

    test('scales linearly for a single traveler', () {
      expect(
        ServicePricing.totalPriceCents(perPersonPriceCents: 20000, travelerCount: 1),
        20000,
      );
    });
  });
}
