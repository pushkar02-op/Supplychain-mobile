import 'package:dio/dio.dart';

import '../core/dio_client.dart';
import '../core/errors/domain_errors.dart';

class AdminLedgerRepository {
  /// Fetch high-level ledger health summary (strictly read-only)
  /// GET /admin/ledger/health
  Future<Map<String, dynamic>> fetchLedgerHealth(int warehouseId) async {
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
        return {
          ...data,
          'status': status,
          'drifted_batches':
              driftedBatches ??
              (driftBatchList is List ? driftBatchList.length : 0),
        };
      }
      throw const FormatException('Expected a map response');
    } catch (e) {
      if (e is UnauthorizedGovernanceError) {
        rethrow;
      }
      return {};
    }
  }

  /// Fetch detailed reconciliation report (strictly read-only)
  /// GET /admin/ledger/reconcile
  Future<List<dynamic>> fetchDriftReport(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/admin/ledger/reconcile',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.data is List) {
        return List<dynamic>.from(resp.data);
      }
      throw const FormatException('Expected a list response');
    } catch (e) {
      if (e is UnauthorizedGovernanceError) {
        rethrow;
      }
      return [];
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
}
