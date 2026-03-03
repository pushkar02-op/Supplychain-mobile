import 'package:dio/dio.dart';
import 'app_error.dart';
import 'domain_errors.dart';

class ErrorMapper {
  static final RegExp _ruleIdRegex = RegExp(r'^[A-Z]{3}-\d{3}$');

  static AppError map(DioException dioException) {
    if (dioException.type == DioExceptionType.connectionTimeout ||
        dioException.type == DioExceptionType.receiveTimeout) {
      return ServiceUnavailableError(
        detail:
            'Connection timed out. Please check your network and try again.',
        statusCode: 503,
      );
    }

    final response = dioException.response;
    if (response == null) {
      return UnknownBackendError(
        detail: dioException.message ?? 'A network error occurred',
      );
    }

    final statusCode = response.statusCode;
    final data = response.data;

    // HTTP Fallbacks first without strong structure payload
    if (statusCode == 429) {
      return RateLimitError(
        detail: 'Too many requests. Please wait and try again.',
        statusCode: 429,
      );
    }
    if (statusCode == 413) {
      return FileTooLargeError(
        detail: 'The file uploaded is too large.',
        statusCode: 413,
      );
    }
    if (statusCode == 503 || statusCode == 502) {
      return ServiceUnavailableError(
        detail: 'Service is temporarily unavailable.',
        statusCode: statusCode,
      );
    }

    String detail = 'An unknown error occurred';
    String? ruleId;
    Map<String, dynamic>? metadata;

    if (data is Map) {
      if (data['detail'] != null) {
        detail = data['detail'].toString();
      }

      final parsedRuleId = data['rule_id']?.toString();
      if (parsedRuleId != null && _ruleIdRegex.hasMatch(parsedRuleId)) {
        ruleId = parsedRuleId;
      }

      if (data['metadata'] is Map) {
        metadata = Map<String, dynamic>.from(data['metadata']);
      }
    } else if (data != null) {
      detail = data.toString();
    }

    if (ruleId != null) {
      switch (ruleId) {
        case 'AUT-007':
          return FinancialLockError(
            detail: detail,
            ruleId: ruleId,
            metadata: metadata,
            statusCode: statusCode,
          );
        case 'AUT-006':
          return DriftLockError(
            detail: detail,
            ruleId: ruleId,
            metadata: metadata,
            statusCode: statusCode,
          );
        case 'AUT-003':
          return LastOwnerError(
            detail: detail,
            ruleId: ruleId,
            metadata: metadata,
            statusCode: statusCode,
          );
        case 'AUT-001':
          return UnauthorizedGovernanceError(
            detail: detail,
            ruleId: ruleId,
            metadata: metadata,
            statusCode: statusCode,
          );
        default:
          return UnknownBackendError(
            detail: detail,
            ruleId: ruleId,
            metadata: metadata,
            statusCode: statusCode,
          );
      }
    }

    return UnknownBackendError(
      detail: detail,
      metadata: metadata,
      statusCode: statusCode,
    );
  }
}
