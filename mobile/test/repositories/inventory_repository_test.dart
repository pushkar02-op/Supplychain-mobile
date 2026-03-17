import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/dio_client.dart';
import 'package:mobile/models/inventory_item.dart';
import 'package:mobile/models/inventory_signal.dart';
import 'package:mobile/models/stock_transaction.dart';
import 'package:mobile/repositories/inventory_repository.dart';

import 'admin_ledger_repository_test.mocks.dart';
import 'package:mockito/mockito.dart';

void main() {
  late MockDio mockDio;
  late InventoryRepository repository;

  final staticMockDio = MockDio();

  setUpAll(() {
    try {
      DioClient.instance = staticMockDio;
    } catch (_) {}
  });

  setUp(() {
    mockDio = staticMockDio;
    reset(mockDio);
    repository = InventoryRepository();
  });

  test('fetchInventory parses numeric strings safely', () async {
    when(
      mockDio.get('/reports/inventory', queryParameters: anyNamed('queryParameters')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/reports/inventory'),
        statusCode: 200,
        data: [
          {
            'item_id': 5,
            'warehouse_id': 1,
            'name': 'Rice',
            'state_qty': '10.500',
            'ledger_qty': '9.000',
            'unit': 'KG',
            'status': 'DRIFT',
            'severity': 'MAJOR',
          },
        ],
      ),
    );

    final result = await repository.fetchInventory(warehouseId: 1);
    expect(result.single, isA<InventoryItem>());
    expect(result.single.quantity, 10.5);
    expect(result.single.ledgerQty, 9.0);
    expect(result.single.name, 'Rice');
  });

  test('fetchTransactions parses missing numeric fields with defaults', () async {
    when(
      mockDio.get('/inventory-txn/', queryParameters: anyNamed('queryParameters')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/inventory-txn/'),
        statusCode: 200,
        data: [
          {
            'id': 7,
            'txn_type': 'OUT',
            'ref_type': 'dispatch_entry',
            'ref_id': '12',
            'raw_qty': '4.5',
            'raw_unit': 'KG',
            'created_at': '2026-03-13T10:00:00Z',
          },
        ],
      ),
    );

    final result = await repository.fetchTransactions(warehouseId: 1, itemId: 5);
    expect(result.single.refId, 12);
    expect(result.single.rawQty, 4.5);
  });

  test('fetchItemSignals parses defaults safely', () async {
    when(
      mockDio.get('/reports/inventory/5/signals', queryParameters: anyNamed('queryParameters')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/reports/inventory/5/signals'),
        statusCode: 200,
        data: {
          'available_stock': '8.0',
          'avg_daily_outflow': null,
          'out_last_7d': '2.0',
          'out_prev_7d': 1,
          'signals': ['WATCH'],
        },
      ),
    );

    final result = await repository.fetchItemSignals(1, 5);
    expect(result, isA<InventorySignal>());
    expect(result.availableStock, 8.0);
    expect(result.avgDailyOutflow, 0);
    expect(result.outLast7d, 2.0);
    expect(result.outPrev7d, 1.0);
  });

  test('stock transaction model parses nested stock entry payload safely', () {
    final tx = StockTransaction.fromJson({
      'id': 1,
      'item': {'id': 2, 'name': 'Tomato'},
      'quantity': '5',
      'batch_quantity': '4.5',
      'unit': 'KG',
      'price_per_unit': '20.25',
      'total_cost': null,
      'source': null,
    });

    expect(tx.itemId, 2);
    expect(tx.itemName, 'Tomato');
    expect(tx.quantity, 5.0);
    expect(tx.currentQuantity, 4.5);
    expect(tx.totalCost, 0);
  });
}
