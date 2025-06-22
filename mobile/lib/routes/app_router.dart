import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/screens/dispatch_entry_screen.dart';
import 'package:mobile/screens/dispatch_list_screen.dart';
import 'package:mobile/screens/map_items_screen.dart';
import 'package:mobile/screens/pdf_view_screen.dart';
import 'package:mobile/screens/rejection_entry_screen.dart';
import 'package:mobile/screens/rejection_list_screen.dart';

import '../auth/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/stock_list_screen.dart';
import '../screens/stock_entry_screen.dart';
import '../screens/order_entry_screen.dart';
import '../screens/invoice_list_screen.dart';
import '../screens/inventory_screen.dart';

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
    GoRoute(
      path: '/dispatch-entries',
      builder: (c, s) => const DispatchListScreen(),
    ),
    GoRoute(
      path: '/dispatch-entry',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CreateOrEditDispatchScreen(data: extra);
      },
    ),
    GoRoute(path: '/invoices', builder: (c, s) => const InvoiceListScreen()),
    GoRoute(
      path: '/pdf-viewer',
      builder: (context, state) {
        final invoiceId = state.extra as int;
        return PdfViewerScreen(invoiceId: invoiceId);
      },
    ),
    GoRoute(
      path: '/rejection-list',
      builder: (context, state) => const RejectionListScreen(),
    ),
    GoRoute(
      path: '/rejection-entry',
      builder: (context, state) => const RejectionEntryScreen(),
    ),
    GoRoute(
      path: '/map-items',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return MapItemsScreen(
          invoiceId: extra['invoice_id'],
          unmappedItems: List<Map<String, dynamic>>.from(
            extra['unmapped_items'],
          ),
        );
      },
    ),
    GoRoute(
      path: '/inventory',
      builder: (context, state) => const InventoryScreen(),
    ),
  ],
);
