// Every GraphQL document the app can send, validated against the backend
// contract. A new data source that invents an operation, a field or an argument
// fails here without needing a server. Documents of features the contract does
// not cover yet are listed in [_notInContractYet]; the list only ever shrinks.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../support/contract_schema.dart';

/// Operation names whose documents are not in the contract (the feature is shown
/// as unavailable or is handled elsewhere). Keep this list honest and short.
const _notInContractYet = <String>{};

// Quotes are written as \x27 (') and \x22 (") to fit in raw strings.
const _q3 = r'\x27\x27\x27';
const _str = '(?:$_q3(.*?)$_q3|\\x22\\x22\\x22(.*?)\\x22\\x22\\x22|\\x27((?:[^\\x27\\\\]|\\\\.)*)\\x27|\\x22((?:[^\\x22\\\\]|\\\\.)*)\\x22)';

// `gql(` then an optional `r`, then a string literal.
final _document = RegExp('gql\\(\\s*r?$_str\\s*\\)', dotAll: true);

// A selection kept in a constant of the same file and spliced into a document (`$_fields`).
final _fragment = RegExp(
  '(?:const|final)\\s+(?:String\\s+)?(_\\w+)\\s*=\\s*r?(?:$_q3(.*?)$_q3|\\x27([^\\x27]*)\\x27)\\s*;',
  dotAll: true,
);

final _classStart = RegExp(r'(?:abstract\s+final\s+|abstract\s+|final\s+)?class\s+(\w+)');
final _staticConstant = RegExp(
  'static\\s+const\\s+(?:String\\s+)?(\\w+)\\s*=\\s*r?(?:$_q3(.*?)$_q3|\\x27([^\\x27]*)\\x27)\\s*;',
  dotAll: true,
);

Map<String, String>? _classConstants;

/// `Class.constant` -> its text, for every static string constant in lib/ (a
/// selection kept in a class and spliced as `${Class.constant}` in a document).
Map<String, String> _allClassConstants() => _classConstants ??= () {
      final found = <String, String>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final m in _classStart.allMatches(source)) {
          final rest = source.substring(m.end);
          final next = _classStart.firstMatch(rest);
          final body = next == null ? rest : rest.substring(0, next.start);
          for (final c in _staticConstant.allMatches(body)) {
            found['${m.group(1)}.${c.group(1)}'] = (c.group(2) ?? c.group(3))!;
          }
        }
      }
      return found;
    }();

/// A document as the app sends it: a non-raw string escapes its variables (`\$`)
/// and may splice in a constant of its file or of another class.
String _text(RegExpMatch match, String source) {
  var text = (match.group(1) ?? match.group(2) ?? match.group(3) ?? match.group(4))!.replaceAll(r'\$', r'$');
  for (final fragment in _fragment.allMatches(source)) {
    final name = fragment.group(1)!;
    final body = (fragment.group(2) ?? fragment.group(3))!;
    text = text.replaceAll('\${$name}', body).replaceAll('\$$name', body);
  }
  for (final entry in _allClassConstants().entries) {
    text = text.replaceAll('\${${entry.key}}', entry.value);
  }
  return text;
}

String _operationName(String document) =>
    RegExp(r'(?:query|mutation)\s+(\w+)').firstMatch(document)?.group(1) ?? '(anonymous)';

/// (file, operation name, problems) for every document in lib/.
List<(String, String, List<String>)> _scan() {
  final schema = ContractSchema.load();
  final found = <(String, String, List<String>)>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    for (final match in _document.allMatches(source)) {
      final text = _text(match, source);
      List<String> problems;
      try {
        problems = schema.validate(gql(text));
      } on Object catch (e) {
        problems = ['cannot be parsed (${e.runtimeType})'];
      }
      found.add((entity.path, _operationName(text), problems));
    }
  }
  return found;
}

void main() {
  test('every document in lib/ is valid against the contract', () {
    final all = _scan();
    expect(all.length, greaterThan(10), reason: 'the scan found too few documents');
    final problems = [
      for (final (file, name, found) in all)
        if (found.isNotEmpty && !_notInContractYet.contains(name)) '$file [$name]: ${found.join('; ')}',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('the allow-list holds only documents that really are invalid (it must not hide valid ones)', () {
    final stillInvalid = {
      for (final (_, name, found) in _scan())
        if (found.isNotEmpty && _notInContractYet.contains(name)) name,
    };
    expect(stillInvalid, _notInContractYet);
  });
}
