// A small schema built from `docs/api/mobile-api-reference.md` (the backend
// contract), and a validator that checks GraphQL documents against it: unknown
// operations, unknown or missing arguments, argument/variable type mismatches,
// unknown fields and selection-set mistakes.
//
// This is not a full GraphQL validator; it exists to catch the mistakes an
// integration actually makes (wrong operation name, field that does not exist,
// `String` where the contract says `Decimal`, a `{ success }` selection on a
// Boolean), by validating the documents the app really sends.

import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:gql/ast.dart';

class ContractArg {
  ContractArg(this.name, this.type, {this.hasDefault = false});

  final String name;
  final String type;
  final bool hasDefault;

  bool get required => type.endsWith('!') && !hasDefault;
}

class ContractField {
  ContractField(this.name, this.type, this.args);

  final String name;
  final String type;
  final Map<String, ContractArg> args;
}

class ContractSchema {
  ContractSchema._(this.queries, this.mutations, this.types);

  final Map<String, ContractField> queries;
  final Map<String, ContractField> mutations;
  final Map<String, Map<String, ContractField>> types;

  static const scalars = {'String', 'ID', 'Int', 'Float', 'Boolean', 'Decimal', 'DateTime', 'Date', 'JSON'};

  static ContractSchema? _cached;

  static ContractSchema load() => _cached ??= parse(File('docs/api/mobile-api-reference.md').readAsStringSync());

  static ContractSchema parse(String markdown) {
    final queries = <String, ContractField>{};
    final mutations = <String, ContractField>{};
    final types = <String, Map<String, ContractField>>{};
    final opLine = RegExp(r'^`(query|mutation) (\w+)(?:\((.*)\))?: (.+)`$');
    final fieldRow = RegExp(r'^\| `([^`]+)` \| `([^`]+)` \|$');
    String? currentType;
    for (final raw in markdown.split('\n')) {
      final line = raw.trimRight();
      final op = opLine.firstMatch(line);
      if (op != null) {
        final field = ContractField(op.group(2)!, op.group(4)!, _parseArgs(op.group(3)));
        (op.group(1) == 'query' ? queries : mutations)[field.name] = field;
        continue;
      }
      if (line.startsWith('#### ')) {
        currentType = line.substring(5).trim();
        types[currentType] = {};
        continue;
      }
      if (line.startsWith('### ') || line.startsWith('## ')) {
        currentType = null;
        continue;
      }
      final row = fieldRow.firstMatch(line);
      if (row != null && currentType != null) {
        final head = row.group(1)!;
        final paren = head.indexOf('(');
        final name = paren < 0 ? head : head.substring(0, paren);
        final args = paren < 0 ? <String, ContractArg>{} : _parseArgs(head.substring(paren + 1, head.length - 1));
        types[currentType]![name] = ContractField(name, row.group(2)!, args);
      }
    }
    return ContractSchema._(queries, mutations, types);
  }

  static Map<String, ContractArg> _parseArgs(String? raw) {
    final out = <String, ContractArg>{};
    if (raw == null || raw.trim().isEmpty) return out;
    for (final part in raw.split(',')) {
      final colon = part.indexOf(':');
      final name = part.substring(0, colon).trim();
      var type = part.substring(colon + 1).trim();
      var hasDefault = false;
      final eq = type.indexOf('=');
      if (eq >= 0) {
        hasDefault = true;
        type = type.substring(0, eq).trim();
      }
      out[name] = ContractArg(name, type, hasDefault: hasDefault);
    }
    return out;
  }

  /// Problems of [document] against this schema; empty when it is valid.
  List<String> validate(DocumentNode document) {
    final problems = <String>[];
    for (final def in document.definitions.whereType<OperationDefinitionNode>()) {
      final isMutation = def.type == OperationType.mutation;
      final roots = isMutation ? mutations : queries;
      final vars = {
        for (final v in def.variableDefinitions) v.variable.name.value: _typeString(v.type),
      };
      for (final sel in def.selectionSet.selections.whereType<FieldNode>()) {
        final name = sel.name.value;
        if (name == '__typename') continue;
        final root = roots[name];
        if (root == null) {
          problems.add('${isMutation ? 'mutation' : 'query'} "$name" does not exist in the contract');
          continue;
        }
        _checkArgs(root, sel, vars, problems, name);
        _checkSelection(root.type, sel, vars, problems, name);
      }
    }
    return problems;
  }

  void _checkArgs(
    ContractField field,
    FieldNode node,
    Map<String, String> vars,
    List<String> problems,
    String path,
  ) {
    final given = {for (final a in node.arguments) a.name.value: a.value};
    for (final name in given.keys) {
      if (!field.args.containsKey(name)) problems.add('$path: argument "$name" does not exist');
    }
    for (final arg in field.args.values) {
      final value = given[arg.name];
      if (value == null) {
        if (arg.required) problems.add('$path: required argument "${arg.name}" is missing');
        continue;
      }
      if (value is VariableNode) {
        final varType = vars[value.name.value];
        if (varType == null) {
          problems.add('$path: variable "\$${value.name.value}" is not declared');
        } else if (!_compatible(arg, varType)) {
          problems.add('$path: argument "${arg.name}" is ${arg.type}${arg.hasDefault ? ' (default)' : ''} but variable '
              '"\$${value.name.value}" is $varType');
        }
      }
    }
  }

  static bool _compatible(ContractArg arg, String varType) {
    String base(String t) => t.replaceAll('!', '');
    if (base(arg.type) != base(varType)) return false;
    // A nullable variable cannot feed a required argument (one without a default).
    if (arg.required && !varType.endsWith('!')) return false;
    return true;
  }

  void _checkSelection(String type, FieldNode node, Map<String, String> vars, List<String> problems, String path) {
    final base = type.replaceAll(RegExp(r'[\[\]!]'), '');
    final selections = node.selectionSet?.selections.whereType<FieldNode>().toList();
    if (scalars.contains(base)) {
      if (selections != null && selections.isNotEmpty) {
        problems.add('$path: "$base" is a scalar and takes no selection set');
      }
      return;
    }
    final fields = types[base];
    if (fields == null) {
      problems.add('$path: type "$base" is unknown in the contract');
      return;
    }
    if (selections == null || selections.isEmpty) {
      problems.add('$path: "$base" is an object and needs a selection set');
      return;
    }
    for (final sel in selections) {
      final name = sel.name.value;
      if (name == '__typename') continue;
      final field = fields[name];
      if (field == null) {
        problems.add('$path: "$base" has no field "$name"');
        continue;
      }
      _checkArgs(field, sel, vars, problems, '$path.$name');
      _checkSelection(field.type, sel, vars, problems, '$path.$name');
    }
  }

  static String _typeString(TypeNode node) {
    if (node is ListTypeNode) return '[${_typeString(node.type)}]${node.isNonNull ? '!' : ''}';
    return '${(node as NamedTypeNode).name.value}${node.isNonNull ? '!' : ''}';
  }
}
