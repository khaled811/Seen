import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/network/graphql_service.dart';
import '../models/service_definition_dto.dart';

/// Raw GraphQL access for the services feature. Returns DTOs, never entities.
///
/// NOTE: these are the app's own field names. The real wire shape is read by the mapping beside this class and every document is checked against `docs/api/` in tests.
abstract interface class ServicesRemoteDataSource {
  Future<Either<Failure, List<ServiceDefinitionDto>>> getAvailableServices();
}

class ServicesRemoteDataSourceImpl implements ServicesRemoteDataSource {
  ServicesRemoteDataSourceImpl({required GraphQLService graphQLService, required AppLanguage language})
      : _graphQLService = graphQLService,
        _language = language;

  final GraphQLService _graphQLService;
  final AppLanguage _language;

  static final _servicesDocument = gql(r'''
    query AvailableServices {
      availableServices {
        id
        code
        nameAr
        nameEn
        category
        isActive
        slaHours
        requiresManagementApproval
        myPrice
        fields {
          id
          stepNumber
          fieldKey
          labelAr
          labelEn
          fieldType
          required
          displayOrder
          isSensitive
          effectiveRules
        }
        documents {
          id
          documentKey
          labelAr
          labelEn
          required
        }
      }
    }
  ''');

  @override
  Future<Either<Failure, List<ServiceDefinitionDto>>> getAvailableServices() {
    return _graphQLService.query<List<ServiceDefinitionDto>>(
      QueryOptions<List<ServiceDefinitionDto>>(
        document: _servicesDocument,
        parserFn: (json) => (json['availableServices'] as List<dynamic>)
            .map((e) => ServiceDefinitionDto.fromServerJson(e as Map<String, dynamic>, _language))
            .toList(),
      ),
    );
  }
}
