import 'json_parsers.dart';

class InventoryItem {
  final int id;
  final int itemId;
  final int warehouseId;
  final String name;
  final double quantity;
  final String unit;
  final String status;
  final String severity;
  final double ledgerQty;
  final List<String> signals;

  const InventoryItem({
    required this.id,
    required this.itemId,
    required this.warehouseId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.status,
    required this.severity,
    required this.ledgerQty,
    this.signals = const [],
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final resolvedId = JsonParsers.parseInt(json['id'] ?? json['item_id']);
    return InventoryItem(
      id: resolvedId,
      itemId: JsonParsers.parseInt(json['item_id'] ?? json['id']),
      warehouseId: JsonParsers.parseInt(json['warehouse_id']),
      name: JsonParsers.parseString(
        json['item_name'] ?? json['name'],
        fallback: 'Unknown',
      ),
      quantity: JsonParsers.parseNum(
        json['quantity'] ?? json['state_qty'] ?? json['available_stock'],
      ),
      unit: JsonParsers.parseString(json['unit']),
      status: JsonParsers.parseString(json['status'], fallback: 'HEALTHY'),
      severity: JsonParsers.parseString(json['severity'], fallback: 'NONE'),
      ledgerQty: JsonParsers.parseNum(json['ledger_qty']),
      signals:
          (json['signals'] as List<dynamic>? ?? const [])
              .map((signal) => JsonParsers.parseString(signal))
              .where((signal) => signal.isNotEmpty)
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_id': itemId,
    'warehouse_id': warehouseId,
    'item_name': name,
    'name': name,
    'quantity': quantity,
    'state_qty': quantity,
    'unit': unit,
    'status': status,
    'severity': severity,
    'ledger_qty': ledgerQty,
    'signals': signals,
  };
}
