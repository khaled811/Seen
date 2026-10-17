import '../../domain/entities/statement.dart';

/// TODO(backend-contract): placeholder (docs/BACKEND_MIGRATION_GAPS.md, section 24).
class StatementFileDto {
  const StatementFileDto({required this.url, required this.fileName});

  factory StatementFileDto.fromJson(Map<String, dynamic> json) =>
      StatementFileDto(url: json['url'] as String, fileName: json['fileName'] as String);

  final String url;
  final String fileName;

  StatementFile toEntity() => StatementFile(url: url, fileName: fileName);
}
