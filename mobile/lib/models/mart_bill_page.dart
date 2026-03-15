import 'mart_bill.dart';

class MartBillPage {
  final int total;
  final int skip;
  final int limit;
  final bool hasMore;
  final List<MartBill> items;

  const MartBillPage({
    required this.total,
    required this.skip,
    required this.limit,
    required this.hasMore,
    required this.items,
  });
}
