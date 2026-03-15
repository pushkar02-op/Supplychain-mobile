import '../../providers/dispatch_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/item_provider.dart';
import '../../providers/mart_bill_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/rejection_provider.dart';
import '../../providers/stock_list_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/warehouse_dashboard_provider.dart';
import 'route_refresh.dart';

bool _registered = false;

void registerRouteRefreshRules() {
  if (_registered) {
    return;
  }
  _registered = true;

  RouteRefreshRegistry.register('/overview', (ref) {
    ref.invalidate(warehouseDashboardProvider);
  });

  RouteRefreshRegistry.register('/orders', (ref) {
    ref.invalidate(orderListProvider);
  });

  RouteRefreshRegistry.register('/stock', (ref) {
    ref.invalidate(stockListProvider);
  });

  RouteRefreshRegistry.register('/dispatch', (ref) {
    ref.invalidate(dispatchListProvider);
  });

  RouteRefreshRegistry.register('/rejection', (ref) {
    ref.invalidate(rejectionListProvider);
  });

  RouteRefreshRegistry.register('/inventory', (ref) {
    ref.invalidate(inventoryListProvider);
  });

  RouteRefreshRegistry.register('/items', (ref) {
    ref.invalidate(itemListProvider);
  });

  RouteRefreshRegistry.register('/mart-bills', (ref) {
    ref.invalidate(martBillProvider);
  });

  RouteRefreshRegistry.register('/profile', (ref) {
    ref.invalidate(currentUserProfileProvider);
  });

  RouteRefreshRegistry.register('/admin/users', (ref) {
    ref.invalidate(userListProvider);
  });
}
