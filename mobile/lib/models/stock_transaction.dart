import 'json_parsers.dart';

class StockTransaction {
  final int id;
  final int itemId;
  final String itemName;
  final double quantity;
  final double currentQuantity;
  final String unit;
  final double pricePerUnit;
  final double totalCost;
  final String source;
  final DateTime? receivedAt;

  const StockTransaction({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.currentQuantity,
    required this.unit,
    required this.pricePerUnit,
    required this.totalCost,
    required this.source,
    this.receivedAt,
  });

  factory StockTransaction.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>?;
    return StockTransaction(
      id: JsonParsers.parseInt(json['id']),
      itemId: JsonParsers.parseInt(json['item_id'] ?? item?['id']),
      itemName: JsonParsers.parseString(
        item?['name'] ?? json['item_name'],
        fallback: 'Unknown',
      ),
      quantity: JsonParsers.parseNum(json['quantity']),
      currentQuantity: JsonParsers.parseNum(
        json['batch_quantity'] ?? json['quantity'],
      ),
      unit: JsonParsers.parseString(json['unit']),
      pricePerUnit: JsonParsers.parseNum(json['price_per_unit']),
      totalCost: JsonParsers.parseNum(json['total_cost']),
      source: JsonParsers.parseString(json['source']),
      receivedAt: JsonParsers.parseDate(
        json['received_at'] ?? json['received_date'] ?? json['created_at'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_id': itemId,
    'quantity': quantity,
    'batch_quantity': currentQuantity,
    'unit': unit,
    'price_per_unit': pricePerUnit,
    'total_cost': totalCost,
    'source': source,
    'received_at': receivedAt?.toIso8601String(),
    'item': {'id': itemId, 'name': itemName},
  };
}
