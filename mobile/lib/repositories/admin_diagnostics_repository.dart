import '../core/dio_client.dart';
import '../models/uom_diagnostic_item.dart';

class AdminDiagnosticsRepository {
  /// Fetch list of items with missing default UOM
  /// GET /admin/diagnostics/uom/missing-default
  Future<List<UomDiagnosticItem>> fetchMissingDefaultUOMItems(
    int warehouseId,
  ) async {
    try {
      final resp = await DioClient.instance.get(
        '/admin/diagnostics/uom/missing-default',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.data is Map) {
        final result = Map<String, dynamic>.from(resp.data as Map);
        return (result['items'] as List<dynamic>? ?? const [])
            .map((item) => UomDiagnosticItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      throw const FormatException('Expected a map response');
    } catch (_) {
      return const [];
    }
  }
}
