import 'app_error.dart';

class FinancialLockError extends AppError {
  FinancialLockError({
    required super.detail,
    super.ruleId,
    super.metadata,
    super.statusCode,
  });
}

class DriftLockError extends AppError {
  DriftLockError({
    required super.detail,
    super.ruleId,
    super.metadata,
    super.statusCode,
  });
}

class LastOwnerError extends AppError {
  LastOwnerError({
    required super.detail,
    super.ruleId,
    super.metadata,
    super.statusCode,
  });
}

class UnauthorizedGovernanceError extends AppError {
  UnauthorizedGovernanceError({
    required super.detail,
    super.ruleId,
    super.metadata,
    super.statusCode,
  });
}

class InactiveUserError extends AppError {
  InactiveUserError({
    required super.detail,
    super.ruleId,
    super.metadata,
    super.statusCode,
  });
}

class RateLimitError extends AppError {
  RateLimitError({
    required super.detail,
    super.ruleId,
    super.metadata,
    super.statusCode,
  });
}

class FileTooLargeError extends AppError {
  FileTooLargeError({
    required super.detail,
    super.ruleId,
    super.metadata,
    super.statusCode,
  });
}

class ServiceUnavailableError extends AppError {
  ServiceUnavailableError({
    required super.detail,
    super.ruleId,
    super.metadata,
    super.statusCode,
  });
}

class UnknownBackendError extends AppError {
  UnknownBackendError({
    required super.detail,
    super.ruleId,
    super.metadata,
    super.statusCode,
  });
}
