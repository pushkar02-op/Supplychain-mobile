import 'json_parsers.dart';

class TopMovingItem {
  final int itemId;
  final String itemName;
  final double totalOut;

  const TopMovingItem({
    required this.itemId,
    required this.itemName,
    required this.totalOut,
  });

  factory TopMovingItem.fromJson(Map<String, dynamic> json) {
    return TopMovingItem(
      itemId: JsonParsers.parseInt(json['item_id']),
      itemName: JsonParsers.parseString(json['item_name']),
      totalOut: JsonParsers.parseNum(json['total_out']),
    );
  }

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'item_name': itemName,
    'total_out': totalOut,
  };
}
