class WarehouseAccess {
  final int id;
  final String name;
  final String? code;

  const WarehouseAccess({
    required this.id,
    required this.name,
    this.code,
  });

  String get displayCode => (code ?? '').trim();

  factory WarehouseAccess.fromJson(Map<String, dynamic> json) {
    return WarehouseAccess(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String?,
    );
  }
}
