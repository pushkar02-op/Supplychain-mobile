class MartBillSummary {
  final int totalBills;
  final int needsReview;
  final int processing;
  final int verified;
  final int totalUnresolvedItems;

  const MartBillSummary({
    this.totalBills = 0,
    this.needsReview = 0,
    this.processing = 0,
    this.verified = 0,
    this.totalUnresolvedItems = 0,
  });

  factory MartBillSummary.fromJson(Map<String, dynamic> json) {
    return MartBillSummary(
      totalBills: (json['total_bills'] as num?)?.toInt() ?? 0,
      needsReview: (json['needs_review'] as num?)?.toInt() ?? 0,
      processing: (json['processing'] as num?)?.toInt() ?? 0,
      verified: (json['verified'] as num?)?.toInt() ?? 0,
      totalUnresolvedItems:
          (json['total_unresolved_items'] as num?)?.toInt() ?? 0,
    );
  }
}
