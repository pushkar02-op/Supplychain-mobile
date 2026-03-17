import 'json_parsers.dart';

class UserWarehouse {
  final int id;
  final String name;
  final String code;

  const UserWarehouse({
    required this.id,
    required this.name,
    required this.code,
  });

  factory UserWarehouse.fromJson(Map<String, dynamic> json) {
    return UserWarehouse(
      id: JsonParsers.parseInt(json['id'] ?? json['warehouse_id']),
      name: JsonParsers.parseString(json['name'], fallback: 'Unknown'),
      code: JsonParsers.parseString(json['code']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'warehouse_id': id,
    'name': name,
    'code': code,
  };
}
