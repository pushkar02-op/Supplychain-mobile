enum UserRole {
  owner,
  manager,
  worker;

  static UserRole fromString(String value) {
    switch (value.toUpperCase()) {
      case 'OWNER':
        return UserRole.owner;
      case 'MANAGER':
        return UserRole.manager;
      case 'WORKER':
        return UserRole.worker;
      default:
        throw ArgumentError('Unknown role: $value');
    }
  }
}
