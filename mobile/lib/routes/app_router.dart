import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../auth/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/stock_list_screen.dart';
import '../screens/stock_entry_screen.dart';
import '../screens/order_entry_screen.dart';

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
      path: '/stock-list',
      builder: (context, state) => const StockListScreen(),
    ),
    GoRoute(path: '/orders', builder: (context, state) => const OrdersScreen()),
    GoRoute(
      path: '/order-entry',
      builder: (context, state) => const OrderEntryScreen(),
    ),
    GoRoute(
      path: '/stock-entry',
      builder: (context, state) => const StockEntryScreen(),
    ),
  ],
);
