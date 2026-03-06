import '../core/dio_client.dart';
import '../core/errors/domain_errors.dart';

class AdminLedgerRepository {
  /// Fetch high-level ledger health summary (strictly read-only)
  /// GET /admin/ledger/health
  Future<Map<String, dynamic>> fetchLedgerHealth() async {
    try {
      final resp = await DioClient.instance.get('/admin/ledger/health');
      if (resp.data is Map) {
        return Map<String, dynamic>.from(resp.data);
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
  /// GET /v1/reports/inventory/reconciliation
  Future<List<dynamic>> fetchDriftReport() async {
    try {
      final resp = await DioClient.instance.get(
        '/reports/inventory/reconciliation',
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
  Future<Map<String, dynamic>> fetchReconciliationDetail(int itemId) async {
    try {
      final resp = await DioClient.instance.get(
        '/reports/inventory/$itemId/reconciliation',
      );
      if (resp.data is Map) {
        return Map<String, dynamic>.from(resp.data);
      }
      throw const FormatException('Expected a map response');
    } catch (e) {
      if (e is UnauthorizedGovernanceError) {
        rethrow;
      }
      return {};
    }
  }
}
