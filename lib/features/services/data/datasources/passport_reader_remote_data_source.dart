import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/file_upload_client.dart';
import '../../domain/entities/passport_reading.dart';
import '../../domain/repositories/passport_reader_repository.dart';

/// [PassportReaderRepository] over the REST endpoint. The picked photo lives in a temporary file
/// of the picker; it is removed as soon as the reading ended.
class PassportReaderRemoteDataSource implements PassportReaderRepository {
  PassportReaderRemoteDataSource({required FileUploadClient client}) : _client = client;

  final FileUploadClient _client;

  @override
  Future<Either<Failure, PassportReading>> read({required String path, required String fileName}) async {
    try {
      final result = await _client.readPassport(path: path, fileName: fileName);
      return result.map((body) => PassportReading(
            allChecksPass: body['allChecksPass'] == true,
            suggestions: [
              for (final s in (body['suggestions'] as List<dynamic>? ?? const []))
                if (s is Map<String, dynamic> && s['key'] is String && s['value'] != null && '${s['value']}'.trim().isNotEmpty)
                  PassportSuggestion(key: s['key'] as String, value: '${s['value']}'.trim(), checked: s['checked'] == true),
            ],
          ));
    } finally {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
