class StockHistoryResponse {
  final StockHistoryReceipt receipt;
  final List<StockHistoryAdjustment> adjustments;
  final bool isVoided;
  final DateTime? voidedAt;

  StockHistoryResponse({
    required this.receipt,
    required this.adjustments,
    required this.isVoided,
    this.voidedAt,
  });

  factory StockHistoryResponse.fromJson(Map<String, dynamic> json) {
    return StockHistoryResponse(
      receipt: StockHistoryReceipt.fromJson(json['receipt']),
      adjustments:
          (json['adjustments'] as List)
              .map((e) => StockHistoryAdjustment.fromJson(e))
              .toList(),
      isVoided: json['is_voided'] ?? false,
      voidedAt:
          json['voided_at'] != null ? DateTime.parse(json['voided_at']) : null,
    );
  }
}

class StockHistoryReceipt {
  final int id;
  final DateTime receivedDate;
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final String? source;

  StockHistoryReceipt({
    required this.id,
    required this.receivedDate,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    this.source,
  });

  factory StockHistoryReceipt.fromJson(Map<String, dynamic> json) {
    return StockHistoryReceipt(
      id: json['id'],
      receivedDate: DateTime.parse(json['received_date']),
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'],
      pricePerUnit: (json['price_per_unit'] as num).toDouble(),
      source: json['source'],
    );
  }
}

class StockHistoryAdjustment {
  final int id;
  final double quantityDelta;
  final String unit;
  final String reason;
  final DateTime createdAt;

  StockHistoryAdjustment({
    required this.id,
    required this.quantityDelta,
    required this.unit,
    required this.reason,
    required this.createdAt,
  });

  factory StockHistoryAdjustment.fromJson(Map<String, dynamic> json) {
    return StockHistoryAdjustment(
      id: json['id'],
      quantityDelta: (json['quantity_delta'] as num).toDouble(),
      unit: json['unit'],
      reason: json['reason'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
