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
      id: json['id'],
      invoiceDate: json['invoice_date'],
      martId: json['mart_id'],
      martName: json['mart_name'],
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      filePath: json['file_path'],
      status: json['status'] ?? 'PROCESSING',
      remarks: json['remarks'],
      lockedAt: json['locked_at'],
      lockedBy: json['locked_by'],
    );
  }
}
