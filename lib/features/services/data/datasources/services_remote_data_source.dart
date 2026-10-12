import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/graphql_service.dart';
import '../../domain/entities/service_booking_request.dart';
import '../../domain/entities/traveler_info.dart';
import '../models/service_booking_result_dto.dart';
import '../models/service_definition_dto.dart';

/// Raw GraphQL access for the services feature. Returns DTOs, never entities.
///
/// TODO(backend-contract): documents below encode a placeholder schema
/// (query/mutation names, argument names, response fields). Update once the
/// real Seen Booking GraphQL schema is confirmed — see the matching TODOs
/// in the DTO files.
abstract interface class ServicesRemoteDataSource {
  Future<Either<Failure, List<ServiceDefinitionDto>>> getAvailableServices();

  Future<Either<Failure, ServiceBookingResultDto>> submitBooking(
    ServiceBookingRequest request,
  );
}

class ServicesRemoteDataSourceImpl implements ServicesRemoteDataSource {
  ServicesRemoteDataSourceImpl({required GraphQLService graphQLService})
      : _graphQLService = graphQLService;

  final GraphQLService _graphQLService;

  static final _servicesDocument = gql(r'''
    query AvailableServices {
      availableServices {
        id
        category
        name
        description
        perPersonPriceAmount
        availability
      }
    }
  ''');

  static final _submitBookingDocument = gql(r'''
    mutation SubmitBooking($serviceId: ID!, $travelers: [TravelerInput!]!) {
      submitBooking(serviceId: $serviceId, travelers: $travelers) {
        requestId
        status
        totalPriceAmount
        createdAt
      }
    }
  ''');

  @override
  Future<Either<Failure, List<ServiceDefinitionDto>>> getAvailableServices() {
    return _graphQLService.query<List<ServiceDefinitionDto>>(
      QueryOptions<List<ServiceDefinitionDto>>(
        document: _servicesDocument,
        parserFn: (json) => (json['availableServices'] as List<dynamic>)
            .map((e) => ServiceDefinitionDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  @override
  Future<Either<Failure, ServiceBookingResultDto>> submitBooking(
    ServiceBookingRequest request,
  ) {
    return _graphQLService.mutate<ServiceBookingResultDto>(
      MutationOptions<ServiceBookingResultDto>(
        document: _submitBookingDocument,
        variables: {
          'serviceId': request.serviceId,
          'travelers': request.travelers.map(_travelerToJson).toList(),
        },
        parserFn: (json) => ServiceBookingResultDto.fromJson(
          json['submitBooking'] as Map<String, dynamic>,
        ),
      ),
    );
  }

  Map<String, dynamic> _travelerToJson(TravelerInfo traveler) => {
        for (final entry in traveler.fieldValues.entries)
          entry.key: switch (entry.value) {
            DateTime date => date.toIso8601String(),
            final value => value,
          },
      };
}
