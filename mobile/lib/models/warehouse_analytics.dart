import 'json_parsers.dart';

class WarehouseAnalytics {
  final String status;
  final int totalBatches;
  final int driftedBatches;
  final int negativeStockBatches;
  final int unhealthyRecords;

  const WarehouseAnalytics({
    required this.status,
    required this.totalBatches,
    required this.driftedBatches,
    required this.negativeStockBatches,
    required this.unhealthyRecords,
  });

  factory WarehouseAnalytics.fromJson(Map<String, dynamic> json) {
    return WarehouseAnalytics(
      status: JsonParsers.parseString(json['status'], fallback: 'unknown'),
      totalBatches: JsonParsers.parseInt(json['total_batches']),
      driftedBatches: JsonParsers.parseInt(json['drifted_batches']),
      negativeStockBatches: JsonParsers.parseInt(json['negative_stock_batches']),
      unhealthyRecords: JsonParsers.parseInt(json['unhealthy_records']),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'total_batches': totalBatches,
    'drifted_batches': driftedBatches,
    'negative_stock_batches': negativeStockBatches,
    'unhealthy_records': unhealthyRecords,
  };
}
