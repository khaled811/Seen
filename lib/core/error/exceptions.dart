/// Data-layer exceptions. Thrown by DataSources, caught by repository
/// implementations and mapped to the matching `Failure`. They must never
/// cross into the domain or presentation layers.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode, this.code});

  final int? statusCode;
  final String? code;
}

final class NetworkException extends AppException {
  const NetworkException(super.message, {this.isTimeout = false});

  final bool isTimeout;
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized']);
}

final class ForbiddenException extends AppException {
  const ForbiddenException([super.message = 'Forbidden']);
}

final class CacheException extends AppException {
  const CacheException(super.message);
}

final class ValidationException extends AppException {
  const ValidationException(super.message, {this.fieldErrors = const {}});

  final Map<String, List<String>> fieldErrors;
}
