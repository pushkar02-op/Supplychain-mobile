import 'json_parsers.dart';

class MartBillItem {
  final int id;
  final int invoiceId;
  final int? itemId;
  final String resolutionStatus;
  final String itemName;
  final String? itemCode;
  final String? storeName;
  final double quantity;
  final String uom;
  final double price;
  final double total;

  MartBillItem({
    required this.id,
    required this.invoiceId,
    this.itemId,
    required this.resolutionStatus,
    required this.itemName,
    this.itemCode,
    this.storeName,
    required this.quantity,
    required this.uom,
    required this.price,
    required this.total,
  });

  bool get isUnresolved => resolutionStatus == 'UNRESOLVED';

  factory MartBillItem.fromJson(Map<String, dynamic> json) {
    return MartBillItem(
      id: JsonParsers.parseInt(json['id']),
      invoiceId: JsonParsers.parseInt(json['invoice_id']),
      itemId: json['item_id'] as int?,
      resolutionStatus: json['resolution_status'] ?? 'UNRESOLVED',
      itemName: json['item_name'] ?? '',
      itemCode: json['item_code'],
      storeName: json['store_name'],
      quantity: JsonParsers.parseNum(json['quantity']),
      uom: json['uom'] ?? '',
      price: JsonParsers.parseNum(json['price']),
      total: JsonParsers.parseNum(json['total']),
    );
  }
}
