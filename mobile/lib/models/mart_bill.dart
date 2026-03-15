import 'json_parsers.dart';

class MartBill {
  final int id;
  final String? invoiceDate;
  final int martId;
  final String? martName;
  final double totalAmount;
  final String? filePath;
  final String status;
  final String? remarks;
  final String? lockedAt;
  final String? lockedBy;

  MartBill({
    required this.id,
    this.invoiceDate,
    required this.martId,
    this.martName,
    required this.totalAmount,
    this.filePath,
    required this.status,
    this.remarks,
    this.lockedAt,
    this.lockedBy,
  });

  factory MartBill.fromJson(Map<String, dynamic> json) {
    return MartBill(
      id: JsonParsers.parseInt(json['id']),
      invoiceDate: json['invoice_date']?.toString(),
      martId: JsonParsers.parseInt(json['mart_id']),
      martName: json['mart_name']?.toString(),
      totalAmount: JsonParsers.parseNum(json['total_amount']),
      filePath: json['file_path']?.toString(),
      status: JsonParsers.parseString(json['status'], fallback: 'PROCESSING'),
      remarks: json['remarks']?.toString(),
      lockedAt: json['locked_at']?.toString(),
      lockedBy: json['locked_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoice_date': invoiceDate,
    'mart_id': martId,
    'mart_name': martName,
    'total_amount': totalAmount,
    'file_path': filePath,
    'status': status,
    'remarks': remarks,
    'locked_at': lockedAt,
    'locked_by': lockedBy,
  };
}
