class WarehouseAccess {
  final int id;
  final String name;

  const WarehouseAccess({required this.id, required this.name});

  factory WarehouseAccess.fromJson(Map<String, dynamic> json) {
    return WarehouseAccess(id: json['id'] as int, name: json['name'] as String);
  }
}
