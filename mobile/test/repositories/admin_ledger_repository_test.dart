import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/dio_client.dart';
import 'package:mobile/core/errors/domain_errors.dart';
import 'package:mobile/repositories/admin_ledger_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<Dio>()])
import 'admin_ledger_repository_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late AdminLedgerRepository repository;

  // Static mock instance to persist across tests because DioClient.instance is late final
  final staticMockDio = MockDio();

  setUpAll(() {
    try {
      DioClient.instance = staticMockDio;
    } catch (_) {
      // already initialized
    }
  });

  setUp(() {
    mockDio = staticMockDio;
    reset(mockDio);
    repository = AdminLedgerRepository();
  });

  group('AdminLedgerRepository', () {
    test('fetchLedgerHealth returns map on success', () async {
      when(mockDio.get('/admin/ledger/health')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/admin/ledger/health'),
          statusCode: 200,
          data: {'status': 'healthy', 'drifted_batches': 0},
        ),
      );

      final result = await repository.fetchLedgerHealth();
      expect(result['status'], 'healthy');
      expect(result['drifted_batches'], 0);
    });

    test('fetchDriftReport returns list on success', () async {
      when(
        mockDio.get(
          '/reports/inventory/reconciliation',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/reports/inventory/reconciliation',
          ),
          statusCode: 200,
          data: [
            {'batch_id': 1, 'drift': 0.5},
          ],
        ),
      );

      final result = await repository.fetchDriftReport();
      expect(result, isA<List>());
      expect(result.length, 1);
      expect(result[0]['batch_id'], 1);
    });

    test('throws UnauthorizedGovernanceError on 403', () async {
      when(mockDio.get(any)).thenThrow(
        UnauthorizedGovernanceError(
          detail: 'Forbidden',
          ruleId: 'AUT-001',
          statusCode: 403,
        ),
      );

      expect(
        () => repository.fetchLedgerHealth(),
        throwsA(isA<UnauthorizedGovernanceError>()),
      );
    });
  });
}
