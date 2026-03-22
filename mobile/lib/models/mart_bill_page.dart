import 'mart_bill.dart';
import 'mart_bill_summary.dart';

class MartBillPage {
  final int total;
  final int skip;
  final int limit;
  final bool hasMore;
  final List<MartBill> items;
  final MartBillSummary summary;

  const MartBillPage({
    required this.total,
    required this.skip,
    required this.limit,
    required this.hasMore,
    required this.items,
    this.summary = const MartBillSummary(),
  });

  factory MartBillPage.fromJson(Map<String, dynamic> data, int fallbackLimit) {
    final rawItems =
        (data['items'] ?? data['results'] ?? const []) as List<dynamic>;
    return MartBillPage(
      total: (data['total'] as num?)?.toInt() ?? rawItems.length,
      skip: (data['skip'] as num?)?.toInt() ?? 0,
      limit: (data['limit'] as num?)?.toInt() ?? fallbackLimit,
      hasMore: data['has_more'] as bool? ?? false,
      items: rawItems
          .map((e) => MartBill.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: data['summary'] is Map
          ? MartBillSummary.fromJson(
              Map<String, dynamic>.from(data['summary'] as Map))
          : const MartBillSummary(),
    );
  }
}
