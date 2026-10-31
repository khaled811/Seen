// ignore: depend_on_referenced_packages
import 'package:gql/ast.dart';
import 'package:fpdart/fpdart.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/network/graphql_service.dart';

import 'contract_schema.dart';

/// One operation the app sent: its name, its variables and the document.
class SentOperation {
  SentOperation(this.name, this.variables, this.document);

  final String name;
  final Map<String, dynamic> variables;
  final DocumentNode document;
}

/// A [GraphQLService] driven by a script, for data-source tests.
///
/// Answers are looked up by operation name (`mutation Login {...}` -> `Login`)
/// and handed to the data source's own `parserFn`, so the real parsing code
/// runs on a realistic response. Every document that is sent is checked
/// against the backend contract (`docs/api/mobile-api-reference.md`); a
/// mismatch fails the test with the list of problems.
class ScriptedGraphQLService implements GraphQLService {
  ScriptedGraphQLService(this.answers, {this.validateContract = true});

  /// Operation name -> the `data` object of the response, or a [Failure].
  final Map<String, Object> answers;
  final bool validateContract;
  final List<SentOperation> sent = [];

  List<SentOperation> where(String name) => sent.where((o) => o.name == name).toList();

  @override
  Future<Either<Failure, T>> query<T>(QueryOptions<T> options) =>
      _run(options.document, options.variables, options.parserFn);

  @override
  Future<Either<Failure, T>> mutate<T>(MutationOptions<T> options) =>
      _run(options.document, options.variables, options.parserFn);

  Future<Either<Failure, T>> _run<T>(
    DocumentNode document,
    Map<String, dynamic> variables,
    T Function(Map<String, dynamic>) parserFn,
  ) async {
    final op = document.definitions.whereType<OperationDefinitionNode>().first;
    final name = op.name?.value ?? '';
    sent.add(SentOperation(name, variables, document));

    if (validateContract) {
      final problems = ContractSchema.load().validate(document);
      if (problems.isNotEmpty) {
        throw StateError('Operation "$name" does not match the backend contract:\n - ${problems.join('\n - ')}');
      }
    }

    final answer = answers[name];
    if (answer == null) throw StateError('No scripted answer for operation "$name"');
    if (answer is Failure) return Left(answer);
    return Right(parserFn(answer as Map<String, dynamic>));
  }
}
