import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/screens/stock_entry_screen.dart';

import '../auth/login_screen.dart';
import '../screens/dashboard_screen.dart';

final storage = FlutterSecureStorage();

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final token = await storage.read(key: 'access_token');
    final isLoggingIn = state.uri.path == '/login';

    if (token == null && !isLoggingIn) return '/login';
    if (token != null && isLoggingIn) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/stock-entry',
      builder: (context, state) => const StockEntryScreen(),
    ),
    // GoRoute(
    //   path: '/stock-entry',
    //   builder: (context, state) {
    //     final entry = state.extra as Map<String, dynamic>?;
    //     return StockEntryScreen(stock: entry);
    //   },
    // ),
  ],
);
