import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/screens/admin_diagnostics_screen.dart';
import 'package:mobile/screens/admin_inventory_drift_screen.dart';
import 'package:mobile/screens/admin_inventory_health_screen.dart';
import 'package:mobile/screens/audit_log_screen.dart';
import 'package:mobile/screens/dispatch_entry_screen.dart';
import 'package:mobile/screens/dispatch_list_screen.dart';
import 'package:mobile/screens/pdf_view_screen.dart';
import 'package:mobile/screens/rejection_entry_screen.dart';
import 'package:mobile/screens/rejection_list_screen.dart';
import 'package:mobile/screens/splash_screen.dart';

import '../auth/login_screen.dart';
import '../core/session/session_controller.dart';
import '../core/session/session_state.dart';
import '../screens/alias_mapping_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/item_detail_screen.dart';
import '../screens/item_list_screen.dart';
import '../screens/item_management_screen.dart';
import '../screens/mart_bill_list_screen.dart';
import '../screens/order_entry_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/stock_entry_screen.dart';
import '../screens/stock_list_screen.dart';
import '../screens/user_list_screen.dart';
import '../screens/warehouse_selection_screen.dart';
import '../widgets/app_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  void auditLog(String message) {
    developer.log(message);
    debugPrint(message);
  }

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      auditLog(
        '[ROUTER_REDIRECT_CHECK] '
        'state=${session.state} '
        'location=${state.uri.path}',
      );
      if (state.uri.path == '/splash' && session.state == SessionState.loading) {
        return null;
      }

      final path = state.uri.path;
      final isSplash = path == '/splash';
      final isLogin = path == '/login';
      final isWarehouseSelect = path == '/warehouse/select';
      final isRestricted = path.startsWith('/admin');

      switch (session.state) {
        case SessionState.loading:
          return '/splash';
        case SessionState.unauthenticated:
          if (!isLogin) {
            auditLog('[ROUTER_REDIRECT] -> /login');
          }
          return isLogin ? null : '/login';
        case SessionState.authenticatedNoWarehouse:
          return isWarehouseSelect ? null : '/warehouse/select';
        case SessionState.ready:
          if (isLogin || isWarehouseSelect || isSplash) {
            auditLog('[ROUTER_REDIRECT] -> /main');
            return '/main';
          }
          if (isRestricted && !session.canManageUsers) {
            auditLog('[ROUTER_REDIRECT] -> /main');
            return '/main';
          }
          if (path == '/dashboard') {
            auditLog('[ROUTER_REDIRECT] -> /main');
            return '/main';
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/warehouse/select',
        builder: (context, state) => const WarehouseSelectionScreen(),
      ),
      GoRoute(path: '/main', builder: (context, state) => const AppScaffold()),
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
      GoRoute(
        path: '/mart-bills',
        name: 'mart_bills',
        builder: (c, s) => const MartBillListScreen(),
      ),
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
        path: '/inventory',
        builder: (context, state) => const InventoryScreen(),
      ),
      GoRoute(path: '/items', builder: (context, state) => const ItemListScreen()),
      GoRoute(
        path: '/item-detail',
        builder: (context, state) {
          final item = state.extra as Map<String, dynamic>;
          return ItemDetailScreen(item: item);
        },
      ),
      GoRoute(
        path: '/item-edit',
        builder: (context, state) => ItemManagementScreen(
          data: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/alias-mapping',
        builder: (context, state) => const AliasMappingScreen(),
      ),
      GoRoute(
        path: '/admin/ledger/health',
        builder: (context, state) => const AdminInventoryHealthScreen(),
      ),
      GoRoute(
        path: '/admin/ledger/drift',
        builder: (context, state) => const AdminInventoryDriftScreen(),
      ),
      GoRoute(
        path: '/admin/uom-diagnostics',
        builder: (context, state) => const AdminDiagnosticsScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UserListScreen(),
      ),
      GoRoute(
        path: '/admin/audit-logs',
        builder: (context, state) => const AuditLogScreen(),
      ),
    ],
  );
});
