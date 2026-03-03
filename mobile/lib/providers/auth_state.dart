import '../core/models/user_role.dart';

class AuthState {
  final bool isLoggedIn;
  final UserRole? role;
  final int? userId;

  const AuthState({this.isLoggedIn = false, this.role, this.userId});
}
