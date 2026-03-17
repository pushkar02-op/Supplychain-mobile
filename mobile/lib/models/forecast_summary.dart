import 'json_parsers.dart';

class ForecastSummary {
  final int itemId;
  final double currentLedgerQty;
  final double? avgDailyOutflow;
  final double? daysToZero;
  final DateTime? projectedStockoutDate;
  final String signal;
  final DateTime? lastRefreshed;

  const ForecastSummary({
    required this.itemId,
    required this.currentLedgerQty,
    this.avgDailyOutflow,
    this.daysToZero,
    required this.projectedStockoutDate,
    required this.signal,
    required this.lastRefreshed,
  });

  factory ForecastSummary.fromJson(Map<String, dynamic> json) {
    return ForecastSummary(
      itemId: JsonParsers.parseInt(json['item_id']),
      currentLedgerQty: JsonParsers.parseNum(json['current_ledger_qty']),
      avgDailyOutflow:
          json['avg_daily_outflow'] == null
              ? null
              : JsonParsers.parseNum(json['avg_daily_outflow']),
      daysToZero:
          json['days_to_zero'] == null
              ? null
              : JsonParsers.parseNum(json['days_to_zero']),
      projectedStockoutDate: JsonParsers.parseDate(json['projected_stockout_date']),
      signal: JsonParsers.parseString(json['signal'], fallback: 'STABLE'),
      lastRefreshed: JsonParsers.parseDate(json['last_refreshed']),
    );
  }

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'current_ledger_qty': currentLedgerQty,
    'avg_daily_outflow': avgDailyOutflow,
    'days_to_zero': daysToZero,
    'projected_stockout_date': projectedStockoutDate?.toIso8601String(),
    'signal': signal,
    'last_refreshed': lastRefreshed?.toIso8601String(),
  };
}
