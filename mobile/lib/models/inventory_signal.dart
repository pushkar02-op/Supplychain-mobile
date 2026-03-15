import 'json_parsers.dart';

class InventorySignal {
  final double availableStock;
  final double avgDailyOutflow;
  final double outLast7d;
  final double outPrev7d;
  final List<String> signals;
  final DateTime? lastReconciliation;

  const InventorySignal({
    required this.availableStock,
    required this.avgDailyOutflow,
    required this.outLast7d,
    required this.outPrev7d,
    required this.signals,
    this.lastReconciliation,
  });

  factory InventorySignal.fromJson(Map<String, dynamic> json) {
    final reconciliation = JsonParsers.parseDate(
      json['last_reconciliation'] ??
          json['last_reconciled_at'] ??
          json['reconciled_at'] ??
          json['reconciliation_at'] ??
          json['updated_at'],
    );
    return InventorySignal(
      availableStock: JsonParsers.parseNum(json['available_stock']),
      avgDailyOutflow: JsonParsers.parseNum(json['avg_daily_outflow']),
      outLast7d: JsonParsers.parseNum(json['out_last_7d']),
      outPrev7d: JsonParsers.parseNum(json['out_prev_7d']),
      signals:
          (json['signals'] as List<dynamic>? ?? const [])
              .map((signal) => JsonParsers.parseString(signal))
              .where((signal) => signal.isNotEmpty)
              .toList(),
      lastReconciliation: reconciliation,
    );
  }

  Map<String, dynamic> toJson() => {
    'available_stock': availableStock,
    'avg_daily_outflow': avgDailyOutflow,
    'out_last_7d': outLast7d,
    'out_prev_7d': outPrev7d,
    'signals': signals,
    'last_reconciliation': lastReconciliation?.toIso8601String(),
  };
}
