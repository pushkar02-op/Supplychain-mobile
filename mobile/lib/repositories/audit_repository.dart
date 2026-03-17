import '../core/dio_client.dart';
import '../core/errors/app_error.dart';
import '../models/audit_log_entry.dart';

class AuditRepository {
  /// Fetch all audit logs (Owner only)
  Future<List<AuditLogEntry>> fetchAuditLogs(
    int warehouseId, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final resp = await DioClient.instance.get(
        '/audit-logs/',
        queryParameters: {
          'warehouse_id': warehouseId,
          'limit': limit,
          'offset': offset,
        },
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to fetch audit logs');
      }
      final data = resp.data as List;
      return data
          .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
