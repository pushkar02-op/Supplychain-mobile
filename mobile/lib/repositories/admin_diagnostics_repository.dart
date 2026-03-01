import '../core/dio_client.dart';

class AdminDiagnosticsRepository {
  /// Fetch list of items with missing default UOM
  /// GET /admin/diagnostics/uom/missing-default
  Future<Map<String, dynamic>> fetchMissingDefaultUOMItems() async {
    try {
      final resp = await DioClient.instance.get(
        '/admin/diagnostics/uom/missing-default',
      );
      if (resp.data is Map) {
        return Map<String, dynamic>.from(resp.data);
      }
      throw const FormatException('Expected a map response');
    } catch (e) {
      rethrow;
    }
  }
}
