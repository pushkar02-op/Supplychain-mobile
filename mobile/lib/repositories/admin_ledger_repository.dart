import 'package:dio/dio.dart';

import '../core/dio_client.dart';
import '../core/errors/domain_errors.dart';
import '../models/drift_item.dart';
import '../models/drift_resolution_request.dart';
import '../models/drift_resolution_result.dart';
import '../models/warehouse_analytics.dart';

class AdminLedgerRepository {
  /// Fetch high-level ledger health summary (strictly read-only)
  /// GET /admin/ledger/health
  Future<WarehouseAnalytics> fetchLedgerHealth(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/admin/ledger/health',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.data is Map) {
        final data = Map<String, dynamic>.from(resp.data as Map);
        final status =
            data['status'] ?? data['ledger_status'] ?? 'unknown';
        final driftedBatches = data['drifted_batches'];
        final driftBatchList = data['drift_batches'];
        return WarehouseAnalytics.fromJson({
          ...data,
          'status': status,
          'drifted_batches':
              driftedBatches ??
              (driftBatchList is List ? driftBatchList.length : 0),
        });
      }
      throw const FormatException('Expected a map response');
    } catch (e) {
      if (e is UnauthorizedGovernanceError) {
        rethrow;
      }
      return const WarehouseAnalytics(
        status: 'unknown',
        totalBatches: 0,
        driftedBatches: 0,
        negativeStockBatches: 0,
        unhealthyRecords: 0,
      );
    }
  }

  /// Fetch detailed reconciliation report (strictly read-only)
  /// GET /admin/ledger/reconcile
  Future<List<DriftItem>> fetchDriftItems(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/admin/ledger/reconcile',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.data is List) {
        final data = resp.data as List<dynamic>;
        return data
            .map((item) => DriftItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      throw const FormatException('Expected a list response');
    } catch (e) {
      if (e is UnauthorizedGovernanceError) {
        rethrow;
      }
      return const [];
    }
  }

  /// GET /v1/reports/inventory/{itemId}/reconciliation
  Future<Map<String, dynamic>?> fetchReconciliationDetail(
    int warehouseId,
    int itemId,
  ) async {
    try {
      final resp = await DioClient.instance.get(
        '/reports/inventory/$itemId/reconciliation',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.data is Map) {
        return Map<String, dynamic>.from(resp.data);
      }
      throw const FormatException('Expected a map response');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    } catch (e) {
      if (e is UnauthorizedGovernanceError) {
        rethrow;
      }
      return {};
    }
  }

  Future<DriftResolutionResult> resolveDrift(
    DriftResolutionRequest request,
    int warehouseId,
  ) async {
    final resp = await DioClient.instance.post(
      '/admin/reconciliation/resolve',
      queryParameters: {'warehouse_id': warehouseId},
      data: request.toJson(),
    );
    if (resp.data is Map) {
      return DriftResolutionResult.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );
    }
    throw const FormatException('Expected a map response');
  }
}
