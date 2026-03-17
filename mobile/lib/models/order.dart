class Order {
  final int id;
  final int itemId;
  final String itemName;
  final String? itemCode;
  final String? martName;
  final DateTime orderDate;
  final double quantityOrdered;
  final double quantityDispatched;
  final String unit;
  final String status;

  Order({
    required this.id,
    required this.itemId,
    required this.itemName,
    this.itemCode,
    this.martName,
    required this.orderDate,
    required this.quantityOrdered,
    required this.quantityDispatched,
    required this.unit,
    required this.status,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      itemId: json['item_id'] as int,
      itemName:
          json['item_name']?.toString() ??
          json['item']?['name']?.toString() ??
          'Unknown Item',
      itemCode:
          json['item_code']?.toString() ?? json['item']?['code']?.toString(),
      martName: json['mart_name']?.toString(),
      orderDate:
          DateTime.tryParse(json['order_date']?.toString() ?? '') ??
          DateTime.now(),
      quantityOrdered: (json['quantity_ordered'] as num?)?.toDouble() ?? 0,
      quantityDispatched:
          (json['quantity_dispatched'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_id': itemId,
      'item_name': itemName,
      'item_code': itemCode,
      'mart_name': martName,
      'order_date': orderDate.toIso8601String().split('T')[0],
      'quantity_ordered': quantityOrdered,
      'quantity_dispatched': quantityDispatched,
      'unit': unit,
      'status': status,
    };
  }
}
