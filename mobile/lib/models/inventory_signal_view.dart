import 'json_parsers.dart';

class InventorySignalView {
  final int itemId;
  final String itemName;
  final String unit;
  final double availableStock;
  final double ledgerQty;
  final String status;
  final String severity;

  const InventorySignalView({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.availableStock,
    required this.ledgerQty,
    required this.status,
    required this.severity,
  });

  factory InventorySignalView.fromJson(Map<String, dynamic> json) {
    return InventorySignalView(
      itemId: JsonParsers.parseInt(json['item_id'] ?? json['id']),
      itemName: JsonParsers.parseString(
        json['item_name'] ?? json['name'],
        fallback: 'Unknown',
      ),
      unit: JsonParsers.parseString(json['unit']),
      availableStock: JsonParsers.parseNum(
        json['available_stock'] ?? json['state_qty'] ?? json['quantity'],
      ),
      ledgerQty: JsonParsers.parseNum(json['ledger_qty']),
      status: JsonParsers.parseString(json['status'], fallback: 'HEALTHY'),
      severity: JsonParsers.parseString(json['severity'], fallback: 'NONE'),
    );
  }

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'item_name': itemName,
    'unit': unit,
    'available_stock': availableStock,
    'ledger_qty': ledgerQty,
    'status': status,
    'severity': severity,
  };
}
