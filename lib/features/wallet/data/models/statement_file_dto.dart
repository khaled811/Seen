import 'dart:convert';

import '../../domain/entities/statement.dart';

/// Wire shape of `accountStatementPdf` (the part the app uses).
class StatementFileDto {
  const StatementFileDto({required this.fileName, required this.contentBase64});

  factory StatementFileDto.fromJson(Map<String, dynamic> json) => StatementFileDto(
        fileName: json['filename'] as String,
        contentBase64: json['contentBase64'] as String,
      );

  final String fileName;
  final String contentBase64;

  /// Throws [FormatException] when the content is not valid base64.
  StatementFile toEntity() => StatementFile(fileName: fileName, bytes: base64Decode(contentBase64));
}
