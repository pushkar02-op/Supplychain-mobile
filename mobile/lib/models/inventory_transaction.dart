import 'json_parsers.dart';

class InventoryTransaction {
  final int id;
  final String txnType;
  final String refType;
  final int refId;
  final double rawQty;
  final String rawUnit;
  final DateTime? createdAt;

  const InventoryTransaction({
    required this.id,
    required this.txnType,
    required this.refType,
    required this.refId,
    required this.rawQty,
    required this.rawUnit,
    this.createdAt,
  });

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) {
    return InventoryTransaction(
      id: JsonParsers.parseInt(json['id']),
      txnType: JsonParsers.parseString(json['txn_type']),
      refType: JsonParsers.parseString(json['ref_type']),
      refId: JsonParsers.parseInt(json['ref_id']),
      rawQty: JsonParsers.parseNum(json['raw_qty'] ?? json['quantity']),
      rawUnit: JsonParsers.parseString(json['raw_unit'] ?? json['unit']),
      createdAt: JsonParsers.parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'txn_type': txnType,
    'ref_type': refType,
    'ref_id': refId,
    'raw_qty': rawQty,
    'raw_unit': rawUnit,
    'created_at': createdAt?.toIso8601String(),
  };
}
