import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/domain_errors.dart';
import 'package:mobile/core/errors/error_mapper.dart';

void main() {
  /// Helper: builds a DioException with optional response payload.
  DioException makeDioException({int? statusCode, Map<String, dynamic>? data}) {
    final requestOptions = RequestOptions(path: '/test');
    return DioException(
      requestOptions: requestOptions,
      response:
          statusCode != null
              ? Response(
                requestOptions: requestOptions,
                statusCode: statusCode,
                data: data,
              )
              : null,
    );
  }

  group('ErrorMapper — rule_id mapping', () {
    test('AUT-007 → FinancialLockError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 403,
          data: {
            'detail': 'Financial lock active',
            'rule_id': 'AUT-007',
            'metadata': {'lock_type': 'full'},
          },
        ),
      );

      expect(error, isA<FinancialLockError>());
      expect(error.detail, 'Financial lock active');
      expect(error.ruleId, 'AUT-007');
      expect(error.statusCode, 403);
      expect(error.metadata?['lock_type'], 'full');
    });

    test('AUT-006 → DriftLockError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 403,
          data: {'detail': 'Drift lock active', 'rule_id': 'AUT-006'},
        ),
      );

      expect(error, isA<DriftLockError>());
      expect(error.detail, 'Drift lock active');
      expect(error.ruleId, 'AUT-006');
      expect(error.statusCode, 403);
    });

    test('AUT-003 → LastOwnerError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 403,
          data: {'detail': 'Cannot remove last owner', 'rule_id': 'AUT-003'},
        ),
      );

      expect(error, isA<LastOwnerError>());
      expect(error.detail, 'Cannot remove last owner');
      expect(error.ruleId, 'AUT-003');
    });

    test('AUT-001 → UnauthorizedGovernanceError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 403,
          data: {'detail': 'Insufficient permissions', 'rule_id': 'AUT-001'},
        ),
      );

      expect(error, isA<UnauthorizedGovernanceError>());
      expect(error.detail, 'Insufficient permissions');
      expect(error.ruleId, 'AUT-001');
    });
  });

  group('ErrorMapper — HTTP status fallback', () {
    test('429 → RateLimitError', () {
      final error = ErrorMapper.map(makeDioException(statusCode: 429));

      expect(error, isA<RateLimitError>());
      expect(error.statusCode, 429);
    });

    test('413 → FileTooLargeError', () {
      final error = ErrorMapper.map(makeDioException(statusCode: 413));

      expect(error, isA<FileTooLargeError>());
      expect(error.statusCode, 413);
    });

    test('503 → ServiceUnavailableError', () {
      final error = ErrorMapper.map(makeDioException(statusCode: 503));

      expect(error, isA<ServiceUnavailableError>());
      expect(error.statusCode, 503);
    });
  });

  group('ErrorMapper — unknown / invalid rule_id', () {
    test('Unknown rule_id (FOO-999) → UnknownBackendError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 400,
          data: {'detail': 'Something went wrong', 'rule_id': 'FOO-999'},
        ),
      );

      expect(error, isA<UnknownBackendError>());
      expect(error.ruleId, 'FOO-999');
      expect(error.detail, 'Something went wrong');
    });

    test('Invalid rule_id format → UnknownBackendError (no ruleId)', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 400,
          data: {'detail': 'Bad request', 'rule_id': 'invalid'},
        ),
      );

      expect(error, isA<UnknownBackendError>());
      expect(error.ruleId, isNull);
      expect(error.detail, 'Bad request');
    });
  });
}
