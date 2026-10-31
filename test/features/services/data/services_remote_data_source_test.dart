// The service catalog against the backend contract: the document is validated
// against `docs/api/mobile-api-reference.md`, the mapping runs on a realistic answer.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/localization/app_language.dart';
import 'package:seen_booking/features/services/data/datasources/services_remote_data_source.dart';
import 'package:seen_booking/features/services/data/repositories/services_repository_impl.dart';

import '../../../support/scripted_graphql_service.dart';

Map<String, dynamic> _service(String id, {Object? price = '85.00', bool active = true, String category = 'egypt'}) => {
      'id': id,
      'code': 'EG_NS_$id',
      'nameAr': 'موافقة $id',
      'nameEn': 'Approval $id',
      'category': category,
      'isActive': active,
      'slaHours': 48,
      'requiresManagementApproval': true,
      'myPrice': price,
      'fields': [
        {
          'id': 'f2',
          'stepNumber': 1,
          'fieldKey': 'passportExpiry',
          'labelAr': 'انتهاء الجواز',
          'labelEn': 'Passport expiry',
          'fieldType': 'date',
          'required': true,
          'displayOrder': 2,
          'isSensitive': false,
          'effectiveRules': jsonEncode({'min_valid_months': 6}),
        },
        {
          'id': 'f1',
          'stepNumber': 1,
          'fieldKey': 'fullName',
          'labelAr': 'الاسم',
          'labelEn': 'Full name',
          'fieldType': 'text',
          'required': true,
          'displayOrder': 1,
          'isSensitive': true,
          'effectiveRules': '{}',
        },
      ],
      'documents': [
        {'id': 'd1', 'documentKey': 'passport', 'labelAr': 'جواز', 'labelEn': 'Passport', 'required': true},
      ],
    };

void main() {
  late ScriptedGraphQLService graphql;
  late ServicesRepositoryImpl repository;

  setUp(() {
    graphql = ScriptedGraphQLService({
      'AvailableServices': {
        'availableServices': [_service('s1'), _service('s2', price: null), _service('s3', active: false)],
      },
    });
    repository = ServicesRepositoryImpl(
      remote: ServicesRemoteDataSourceImpl(graphQLService: graphql, language: AppLanguage('en')),
    );
  });

  test('maps the catalog; a service without a price or inactive is not bookable', () async {
    final result = await repository.getAvailableServices();
    final services = (result as Right).value as List;
    expect(services, hasLength(3));
    final first = services.first;
    expect(first.name, 'Approval s1');
    expect(first.perPersonPriceCents, 8500);
    expect(first.isBookable, isTrue);
    expect(first.code, 'EG_NS_s1');
    expect(first.slaHours, 48);
    expect(first.requiresApproval, isTrue);
    expect(first.fields.map((f) => f.key), ['fullName', 'passportExpiry']);
    expect(first.fields.last.type, FieldType.date);
    expect(first.fields.last.minValidMonths, 6);
    expect(first.fields.last.definitionId, 'f2');
    expect(first.documents.single.key, 'passport');
    expect(services[1].isBookable, isFalse);
    expect(services[2].isBookable, isFalse);
  });

  test('a medical service is not bookable: the contract cannot carry its hospital', () async {
    graphql = ScriptedGraphQLService({
      'AvailableServices': {
        'availableServices': [_service('m1', category: 'medical_jordan')],
      },
    });
    repository = ServicesRepositoryImpl(
      remote: ServicesRemoteDataSourceImpl(graphQLService: graphql, language: AppLanguage('en')),
    );
    final services = ((await repository.getAvailableServices()) as Right).value as List;
    expect(services.single.isBookable, isFalse);
  });
}
