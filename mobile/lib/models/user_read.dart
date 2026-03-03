/// Minimal DTO mirroring backend UserRead schema.
class UserRead {
  final int id;
  final String username;
  final String fullName;
  final String role;
  final bool isAdmin;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserRead({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isAdmin,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserRead.fromJson(Map<String, dynamic> json) {
    return UserRead(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'WORKER',
      isAdmin: json['is_admin'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
