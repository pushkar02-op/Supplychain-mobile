import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/providers/auth_state.dart';
import 'package:mobile/screens/admin_diagnostics_screen.dart';
import 'package:mobile/screens/admin_inventory_drift_screen.dart';
import 'package:mobile/screens/admin_inventory_health_screen.dart';
import 'package:mobile/screens/dispatch_entry_screen.dart';
import 'package:mobile/screens/dispatch_list_screen.dart';
import 'package:mobile/screens/map_items_screen.dart';
import 'package:mobile/screens/pdf_view_screen.dart';
import 'package:mobile/screens/rejection_entry_screen.dart';
import 'package:mobile/screens/rejection_list_screen.dart';

import '../auth/login_screen.dart';
import '../providers/auth_provider.dart';
import '../screens/alias_mapping_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/item_list_screen.dart';
import '../screens/item_management_screen.dart';
import '../screens/mart_bill_list_screen.dart';
import '../screens/order_entry_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/stock_entry_screen.dart';
import '../screens/stock_list_screen.dart';
import '../widgets/app_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  debugPrint(
    '[ROUTER_PROVIDER] Rebuilding GoRouter. AuthState: ${authState.value}',
  );

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthStateListenable(authState),
    redirect: (context, state) {
      debugPrint(
        '[ROUTER] redirect check. Path: ${state.uri.path}, AuthState: ${authState.value}',
      );
      // If auth state is loading, maybe show a splash?
      // For now, if loading, we wait.
      if (authState.isLoading || authState.hasError) {
        debugPrint('[ROUTER] Auth loading or error. Staying put.');
        return null;
      }

      final isLoggedIn = authState.value?.isLoggedIn ?? false;
      final isAdmin = authState.value?.isAdmin ?? false;
      final isLoggingIn = state.uri.path == '/login';
      final isRestricted = state.uri.path.startsWith('/admin');

      if (!isLoggedIn && !isLoggingIn) {
        debugPrint('[ROUTER] Not logged in, redirecting to /login');
        return '/login';
      }
      if (isLoggedIn && isLoggingIn) {
        debugPrint('[ROUTER] Logged in, redirecting to /main');
        return '/main';
      }
      // Legacy dashboard route redirects to main
      if (isLoggedIn && state.uri.path == '/dashboard') {
        debugPrint('[ROUTER] Redirecting /dashboard to /main');
        return '/main';
      }

      // Admin Guard
      if (isRestricted && !isAdmin) {
        return '/main';
      }

      debugPrint('[ROUTER] No redirect needed.');
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/main', builder: (context, state) => const AppScaffold()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/stock-list',
        builder: (context, state) => const StockListScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
      ),
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
        path: '/map-items',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return MapItemsScreen(
            billId: extra['invoice_id'],
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
      GoRoute(
        path: '/items',
        builder: (context, state) => const ItemListScreen(),
      ),
      GoRoute(
        path: '/item-edit',
        builder:
            (context, state) => ItemManagementScreen(
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
    ],
  );
});

// Helper to convert AsyncValue to Listenable for GoRouter
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(this._state);
  final AsyncValue<AuthState> _state;
}
