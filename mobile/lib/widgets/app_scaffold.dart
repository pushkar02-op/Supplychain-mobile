import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/app_navigation.dart';
import '../core/navigation/create_result.dart';
import '../core/navigation/route_refresh.dart';
import '../providers/order_provider.dart';
import '../providers/warehouse_dashboard_provider.dart';
import '../providers/stock_list_provider.dart';
import '../ui/theme/agro_colors.dart';
import 'warehouse_selector.dart';

/// Main application scaffold with bottom navigation.
/// Hosts the primary tabs: Overview, Stock, Orders, Dispatch, More.
class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  static const _tabPaths = <String>[
    '/overview',
    '/stock',
    '/orders',
    '/dispatch',
    '/more',
  ];

  String? _lastHandledLocation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.path;
    if (_lastHandledLocation == location) {
      return;
    }

    _lastHandledLocation = location;
    debugPrint('[NAV] $location');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      RouteRefreshRegistry.run(location, ref);
    });
  }

  _RouteMeta _routeMetaForLocation(String location) {
    if (location.startsWith('/overview')) {
      return const _RouteMeta(
        currentIndex: 0,
        title: 'Overview',
        showWarehouseSelector: true,
        showRefreshAction: true,
        fabType: _FabType.none,
      );
    }
    if (location.startsWith('/stock')) {
      return const _RouteMeta(
        currentIndex: 1,
        title: 'Stock',
        showWarehouseSelector: true,
        showRefreshAction: false,
        fabType: _FabType.stock,
      );
    }
    if (location.startsWith('/orders')) {
      return const _RouteMeta(
        currentIndex: 2,
        title: 'Orders',
        showWarehouseSelector: true,
        showRefreshAction: false,
        fabType: _FabType.orders,
      );
    }
    if (location.startsWith('/dispatch')) {
      return const _RouteMeta(
        currentIndex: 3,
        title: 'Dispatch',
        showWarehouseSelector: true,
        showRefreshAction: false,
        fabType: _FabType.dispatch,
      );
    }
    return const _RouteMeta(
      currentIndex: 4,
      title: 'More',
      showWarehouseSelector: false,
      showRefreshAction: false,
      fabType: _FabType.none,
    );
  }

  PreferredSizeWidget _buildAppBar(_RouteMeta meta) {
    return AppBar(
      title:
          meta.showWarehouseSelector
              ? WarehouseSelector(screenTitle: meta.title)
              : Text(meta.title),
      backgroundColor: AgroColors.surface,
      foregroundColor: AgroColors.textPrimary,
      elevation: 1,
      toolbarHeight: meta.showWarehouseSelector ? 72 : null,
      actions: [
        if (meta.showRefreshAction)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(warehouseDashboardProvider),
            tooltip: 'Refresh',
          ),
      ],
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context, _RouteMeta meta) {
    if (meta.fabType == _FabType.orders) {
      return FloatingActionButton.extended(
        onPressed: () async {
          final result = await AppNavigation.createOrder<CreateResult>(context);
          if (result == CreateResult.created) {
            ref.invalidate(orderListProvider);
          }
        },
        backgroundColor: AgroColors.success.text,
        icon: const Icon(Icons.add),
        label: const Text('Create Order'),
        heroTag: 'orders-add-fab',
      );
    }

    if (meta.fabType == _FabType.stock) {
      return Semantics(
        label: 'add-stock-action',
        button: true,
        onTap: () async {
          final result = await AppNavigation.receiveStock<CreateResult>(context);
          if (result == CreateResult.created) {
            ref.invalidate(stockListProvider);
          }
        },
        child: FloatingActionButton.extended(
          onPressed: () async {
            final result = await AppNavigation.receiveStock<CreateResult>(
              context,
            );
            if (result == CreateResult.created) {
              ref.invalidate(stockListProvider);
            }
          },
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Receive Stock'),
          heroTag: 'stock-add-fab',
        ),
      );
    }

    if (meta.fabType == _FabType.dispatch) {
      return FloatingActionButton.extended(
        onPressed: () => AppNavigation.goOrders(context),
        icon: const Icon(Icons.local_shipping),
        label: const Text('Dispatch Order'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        heroTag: 'dispatch-order-fab',
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final meta = _routeMetaForLocation(location);

    return Scaffold(
      appBar: _buildAppBar(meta),
      body: widget.child,
      floatingActionButton: _buildFloatingActionButton(context, meta),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: meta.currentIndex,
        onTap: (index) {
          final target = _tabPaths[index];
          if (target == '/overview') {
            AppNavigation.goOverview(context);
          } else if (target == '/stock') {
            AppNavigation.goStock(context);
          } else if (target == '/orders') {
            AppNavigation.goOrders(context);
          } else if (target == '/dispatch') {
            AppNavigation.goDispatch(context);
          } else {
            AppNavigation.goMore(context);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Dispatch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

enum _FabType { none, orders, stock, dispatch }

class _RouteMeta {
  const _RouteMeta({
    required this.currentIndex,
    required this.title,
    required this.showWarehouseSelector,
    required this.showRefreshAction,
    required this.fabType,
  });

  final int currentIndex;
  final String title;
  final bool showWarehouseSelector;
  final bool showRefreshAction;
  final _FabType fabType;
}
