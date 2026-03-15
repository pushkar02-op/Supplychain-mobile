import 'json_parsers.dart';

class InventoryBatch {
  final int id;
  final double quantity;
  final String unit;
  final DateTime? receivedAt;

  const InventoryBatch({
    required this.id,
    required this.quantity,
    required this.unit,
    this.receivedAt,
  });

  factory InventoryBatch.fromJson(Map<String, dynamic> json) {
    return InventoryBatch(
      id: JsonParsers.parseInt(json['id'] ?? json['batch_id']),
      quantity: JsonParsers.parseNum(json['quantity'] ?? json['qty']),
      unit: JsonParsers.parseString(json['unit']),
      receivedAt: JsonParsers.parseDate(json['received_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'batch_id': id,
    'quantity': quantity,
    'qty': quantity,
    'unit': unit,
    'received_at': receivedAt?.toIso8601String(),
  };
}
