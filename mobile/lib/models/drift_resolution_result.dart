class DriftResolutionResult {
  final bool success;
  final int adjustmentTxnId;

  const DriftResolutionResult({
    required this.success,
    required this.adjustmentTxnId,
  });

  factory DriftResolutionResult.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return DriftResolutionResult(
      success: json['success'] == true,
      adjustmentTxnId: parseInt(json['adjustment_txn_id']),
    );
  }
}
