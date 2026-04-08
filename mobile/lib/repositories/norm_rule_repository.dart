import '../core/dio_client.dart';
import '../core/errors/app_error.dart';
import '../models/norm_suggestion.dart';

class NormRuleRepository {
  /// Fetch normalization suggestions for all MAPPED items in a bill.
  Future<NormSuggestionsResponse> fetchNormSuggestions({
    required int warehouseId,
    required int billId,
  }) async {
    try {
      final resp = await DioClient.instance.get(
        '/mart-bill-items/$billId/norm-suggestions',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        return NormSuggestionsResponse.fromJson(
          Map<String, dynamic>.from(resp.data as Map),
        );
      }
      throw AppError(detail: 'Failed to load normalization suggestions');
    } catch (e) {
      rethrow;
    }
  }

  /// Confirm normalization rules for bill items.
  ///
  /// [rules] is a list of maps with keys:
  ///   bill_item_id, rule_type, rule_value, accepted
  Future<Map<String, dynamic>> confirmRules({
    required int warehouseId,
    required int billId,
    required List<Map<String, dynamic>> rules,
  }) async {
    try {
      final resp = await DioClient.instance.post(
        '/mart-bill-items/$billId/confirm-rules',
        queryParameters: {'warehouse_id': warehouseId},
        data: {'rules': rules},
      );
      if (resp.statusCode == 200) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
      throw AppError(detail: 'Failed to confirm rules');
    } catch (e) {
      rethrow;
    }
  }

  /// Generate stock entries from a verified bill.
  Future<GenerateStockResponse> generateStock({
    required int warehouseId,
    required int billId,
  }) async {
    try {
      final resp = await DioClient.instance.post(
        '/mart-bills/$billId/generate-stock',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        return GenerateStockResponse.fromJson(
          Map<String, dynamic>.from(resp.data as Map),
        );
      }
      throw AppError(detail: 'Failed to generate stock entries');
    } catch (e) {
      rethrow;
    }
  }
}
