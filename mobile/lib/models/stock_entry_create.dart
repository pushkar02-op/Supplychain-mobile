class StockEntryCreate {
  final int itemId;
  final String receivedDate;
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final double totalCost;
  final String? source;

  StockEntryCreate({
    required this.itemId,
    required this.receivedDate,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.totalCost,
    this.source,
  });

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'received_date': receivedDate,
    'quantity': quantity,
    'unit': unit,
    'price_per_unit': pricePerUnit,
    'total_cost': totalCost,
    'source': source,
  };
}
