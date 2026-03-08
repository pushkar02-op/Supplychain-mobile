class Inventory {
  final int id;
  final String itemName;
  final double quantity;
  final String unit;
  final String status;
  final String severity;
  final double ledgerQty;

  Inventory({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.status = 'HEALTHY',
    this.severity = 'NONE',
    this.ledgerQty = 0,
  });

  factory Inventory.fromJson(Map<String, dynamic> json) {
    return Inventory(
      id: json['id'] ?? (json['item_id'] as int),
      itemName: json['item_name'] ?? json['name'] ?? '',
      quantity: (json['quantity'] ?? json['state_qty'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      status: json['status'] ?? 'HEALTHY',
      severity: json['severity'] ?? 'NONE',
      ledgerQty: (json['ledger_qty'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_id': id,
    'item_name': itemName,
    'name': itemName,
    'quantity': quantity,
    'state_qty': quantity,
    'unit': unit,
    'status': status,
    'severity': severity,
    'ledger_qty': ledgerQty,
  };
}
