class DriftItem {
  final int batchId;
  final int itemId;
  final int warehouseId;
  final double stateQty;
  final double ledgerQty;
  final double drift;
  final String? itemName;
  final String? severity;

  DriftItem({
    required this.batchId,
    required this.itemId,
    required this.warehouseId,
    required this.stateQty,
    required this.ledgerQty,
    required this.drift,
    this.itemName,
    this.severity,
  });

  factory DriftItem.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return DriftItem(
      batchId: json['batch_id'] as int? ?? 0,
      itemId: json['item_id'] as int? ?? 0,
      warehouseId: json['warehouse_id'] as int? ?? 0,
      stateQty: parseNum(json['state_qty']),
      ledgerQty: parseNum(json['ledger_qty']),
      drift: parseNum(json['drift']),
      itemName: json['item_name'] as String?,
      severity: json['severity'] as String?,
    );
  }
}
