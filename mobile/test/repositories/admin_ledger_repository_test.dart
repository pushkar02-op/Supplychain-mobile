import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/dio_client.dart';
import 'package:mobile/core/errors/domain_errors.dart';
import 'package:mobile/models/drift_item.dart';
import 'package:mobile/models/drift_resolution_request.dart';
import 'package:mobile/models/drift_resolution_result.dart';
import 'package:mobile/models/warehouse_analytics.dart';
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
    test('fetchLedgerHealth returns analytics model on success', () async {
      when(
        mockDio.get(
          '/admin/ledger/health',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/admin/ledger/health'),
          statusCode: 200,
          data: {
            'ledger_status': 'healthy',
            'drift_batches': [],
          },
        ),
      );

      final result = await repository.fetchLedgerHealth(1);
      expect(result, isA<WarehouseAnalytics>());
      expect(result.status, 'healthy');
      expect(result.driftedBatches, 0);

      verify(
        mockDio.get(
          '/admin/ledger/health',
          queryParameters: {'warehouse_id': 1},
        ),
      ).called(1);
    });

    test('fetchDriftItems parses drift items when numbers returned', () async {
      when(
        mockDio.get(
          '/admin/ledger/reconcile',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/admin/ledger/reconcile'),
          statusCode: 200,
          data: [
            {
              'batch_id': 1,
              'item_id': 10,
              'warehouse_id': 1,
              'state_qty': 12.5,
              'ledger_qty': 10.0,
              'drift': 2.5,
              'item_name': 'Tomato',
              'severity': 'CRITICAL',
            },
          ],
        ),
      );

      final result = await repository.fetchDriftItems(1);
      expect(result, isA<List<DriftItem>>());
      expect(result.length, 1);
      expect(result[0].batchId, 1);
      expect(result[0].stateQty, 12.5);
      expect(result[0].ledgerQty, 10.0);
      expect(result[0].drift, 2.5);
      expect(result[0].itemName, 'Tomato');

      verify(
        mockDio.get(
          '/admin/ledger/reconcile',
          queryParameters: {'warehouse_id': 1},
        ),
      ).called(1);
    });

    test('fetchDriftItems parses drift items when numeric strings returned', () async {
      when(
        mockDio.get(
          '/admin/ledger/reconcile',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/admin/ledger/reconcile'),
          statusCode: 200,
          data: [
            {
              'batch_id': 2,
              'item_id': 11,
              'warehouse_id': 1,
              'state_qty': '9.500',
              'ledger_qty': '8.000',
              'drift': '1.500',
            },
          ],
        ),
      );

      final result = await repository.fetchDriftItems(1);
      expect(result.single.batchId, 2);
      expect(result.single.stateQty, 9.5);
      expect(result.single.ledgerQty, 8.0);
      expect(result.single.drift, 1.5);
    });

    test('throws UnauthorizedGovernanceError on 403', () async {
      when(
        mockDio.get(any, queryParameters: anyNamed('queryParameters')),
      ).thenThrow(
        UnauthorizedGovernanceError(
          detail: 'Forbidden',
          ruleId: 'AUT-001',
          statusCode: 403,
        ),
      );

      expect(
        () => repository.fetchLedgerHealth(1),
        throwsA(isA<UnauthorizedGovernanceError>()),
      );
    });

    test('resolveDrift parses response correctly', () async {
      when(
        mockDio.post(
          '/admin/reconciliation/resolve',
          queryParameters: anyNamed('queryParameters'),
          data: anyNamed('data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/admin/reconciliation/resolve'),
          statusCode: 200,
          data: {
            'success': true,
            'adjustment_txn_id': 42,
          },
        ),
      );

      final result = await repository.resolveDrift(
        const DriftResolutionRequest(
          batchId: 5,
          resolutionType: 'state_to_ledger',
          notes: 'Fix missing ledger txn',
        ),
        1,
      );

      expect(result, isA<DriftResolutionResult>());
      expect(result.success, isTrue);
      expect(result.adjustmentTxnId, 42);

      verify(
        mockDio.post(
          '/admin/reconciliation/resolve',
          queryParameters: {'warehouse_id': 1},
          data: {
            'batch_id': 5,
            'resolution_type': 'state_to_ledger',
            'notes': 'Fix missing ledger txn',
          },
        ),
      ).called(1);
    });
  });
}
