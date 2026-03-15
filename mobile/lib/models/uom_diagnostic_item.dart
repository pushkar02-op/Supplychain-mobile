import 'json_parsers.dart';

class UomDiagnosticItem {
  final int id;
  final String name;
  final String itemCode;

  const UomDiagnosticItem({
    required this.id,
    required this.name,
    required this.itemCode,
  });

  factory UomDiagnosticItem.fromJson(Map<String, dynamic> json) {
    return UomDiagnosticItem(
      id: JsonParsers.parseInt(json['id']),
      name: JsonParsers.parseString(json['name'], fallback: 'Unknown Item'),
      itemCode: JsonParsers.parseString(json['item_code'], fallback: 'N/A'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'item_code': itemCode,
  };
}
