import '../../../../core/config/debug_fallbacks.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../models/service_definition_dto.dart';
import 'services_remote_data_source.dart';

/// DEBUG ONLY — decorates a real [ServicesRemoteDataSource] and, only when a
/// real call fails in a debug build, substitutes a canned MVP catalog. Same
/// pattern (and the same reasoning) as `WalletRemoteDataSourceDebugFallback`:
/// `kDebugMode` is a compile-time constant, so every fallback branch below
/// is dead-code-eliminated in release — this can never surface fake service
/// data to a real user.
class DebugFallbackServicesRemoteDataSource implements ServicesRemoteDataSource {
  DebugFallbackServicesRemoteDataSource(this._real);

  final ServicesRemoteDataSource _real;

  @override
  Future<Either<Failure, List<ServiceDefinitionDto>>> getAvailableServices() async {
    final result = await _real.getAvailableServices();
    if (debugFallbacksEnabled && result.isLeft()) return const Right(_mockCatalog);
    return result;
  }
}

// Placeholder pricing pending real business input: $150/$200 per person.
const _mockCatalog = [
  ServiceDefinitionDto(
    id: 'egypt_national_security',
    category: 'egypt_national_security',
    name: 'Egypt National Security Approval',
    description: 'National Security (الأمن الوطني) travel approval.',
    perPersonPriceAmount: '150.00',
    availability: 'available',
  ),
  ServiceDefinitionDto(
    id: 'egypt_military_intelligence',
    category: 'egypt_military_intelligence',
    name: 'Egypt Military Intelligence Approval',
    description: 'Military Intelligence (المخابرات الحربية) travel approval.',
    perPersonPriceAmount: '200.00',
    availability: 'available',
  ),
  ServiceDefinitionDto(
    id: 'egypt_airline_circular',
    category: 'egypt_airline_circular',
    name: 'Egypt Airline Circular',
    description: 'Scaffolded for subtask 7.2 — not yet bookable.',
    perPersonPriceAmount: '0.00',
    availability: 'coming_soon',
  ),
  ServiceDefinitionDto(
    id: 'jordan_approvals',
    category: 'jordan_approvals',
    name: 'Jordan Approvals',
    description: 'Scaffolded for subtask 7.3 — not yet bookable.',
    perPersonPriceAmount: '0.00',
    availability: 'coming_soon',
  ),
];
