/// Base class for all application exceptions.
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Network related errors (no internet, timeout).
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

/// Unauthorized errors (401).
class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, {super.code});
}

/// Server validation errors (400, 422).
class ValidationException extends AppException {
  final Map<String, dynamic>? errors;
  const ValidationException(super.message, {super.code, this.errors});
}

/// Server internal errors (500).
class ServerException extends AppException {
  const ServerException(super.message, {super.code});
}

/// Configuration errors (409) - e.g. Missing UOM.
class ConfigurationException extends AppException {
  const ConfigurationException(super.message, {super.code});
}

/// Catch-all for other errors.
class UnknownException extends AppException {
  final dynamic originalError;
  const UnknownException(super.message, {super.code, this.originalError});
}
