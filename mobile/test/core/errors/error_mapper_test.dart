import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/domain_errors.dart';
import 'package:mobile/core/errors/error_mapper.dart';

void main() {
  /// Helper: build a [DioException] with a structured JSON response body.
  DioException makeDioException({
    required int statusCode,
    Map<String, dynamic>? data,
  }) {
    final requestOptions = RequestOptions(path: '/test');
    return DioException(
      requestOptions: requestOptions,
      response: Response(
        requestOptions: requestOptions,
        statusCode: statusCode,
        data: data,
      ),
    );
  }

  group('ErrorMapper.map — rule_id mappings', () {
    test('AUT-001 → UnauthorizedGovernanceError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 403,
          data: {
            'detail': 'Insufficient permissions',
            'rule_id': 'AUT-001',
            'metadata': {
              'allowed_roles': ['owner'],
            },
          },
        ),
      );

      expect(error, isA<UnauthorizedGovernanceError>());
      expect(error.ruleId, 'AUT-001');
      expect(error.detail, 'Insufficient permissions');
    });

    test('AUT-003 → LastOwnerError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 403,
          data: {
            'detail': 'Cannot remove the last owner',
            'rule_id': 'AUT-003',
            'metadata': {},
          },
        ),
      );

      expect(error, isA<LastOwnerError>());
      expect(error.ruleId, 'AUT-003');
    });

    test('AUT-005 → InactiveUserError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 403,
          data: {
            'detail': 'Inactive user',
            'rule_id': 'AUT-005',
            'metadata': {},
          },
        ),
      );

      expect(error, isA<InactiveUserError>());
      expect(error.ruleId, 'AUT-005');
      expect(error.detail, 'Inactive user');
    });

    test('AUT-006 → DriftLockError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 403,
          data: {
            'detail': 'Drift lock active',
            'rule_id': 'AUT-006',
            'metadata': {},
          },
        ),
      );

      expect(error, isA<DriftLockError>());
      expect(error.ruleId, 'AUT-006');
    });

    test('AUT-007 → FinancialLockError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 403,
          data: {
            'detail': 'Financial period locked',
            'rule_id': 'AUT-007',
            'metadata': {},
          },
        ),
      );

      expect(error, isA<FinancialLockError>());
      expect(error.ruleId, 'AUT-007');
      expect(error.detail, 'Financial period locked');
    });

    test('Unknown rule_id → UnknownBackendError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 400,
          data: {
            'detail': 'Something unexpected',
            'rule_id': 'XYZ-999',
            'metadata': {},
          },
        ),
      );

      expect(error, isA<UnknownBackendError>());
      expect(error.ruleId, 'XYZ-999');
    });
  });

  group('ErrorMapper.map — HTTP status fallbacks', () {
    test('HTTP 429 → RateLimitError', () {
      final error = ErrorMapper.map(
        makeDioException(statusCode: 429, data: {'detail': 'Too many'}),
      );

      expect(error, isA<RateLimitError>());
      expect(error.statusCode, 429);
    });

    test('HTTP 413 → FileTooLargeError', () {
      final error = ErrorMapper.map(
        makeDioException(
          statusCode: 413,
          data: {'detail': 'Payload too large'},
        ),
      );

      expect(error, isA<FileTooLargeError>());
      expect(error.statusCode, 413);
    });
  });
}
