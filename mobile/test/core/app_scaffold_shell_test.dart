import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/session/session.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/session/session_state.dart';
import 'package:mobile/models/stock_transaction.dart';
import 'package:mobile/models/warehouse_access.dart';
import 'package:mobile/providers/dispatch_provider.dart';
import 'package:mobile/providers/overview_provider.dart';
import 'package:mobile/providers/order_provider.dart';
import 'package:mobile/providers/stock_list_provider.dart';
import 'package:mobile/repositories/dispatch_repository.dart';
import 'package:mobile/repositories/order_repository.dart';
import 'package:mobile/repositories/stock_repository.dart';
import 'package:mobile/routes/app_router.dart';
import 'package:mobile/screens/dispatch_list_screen.dart';
import 'package:mobile/screens/more_hub_screen.dart';
import 'package:mobile/screens/orders_screen.dart';
import 'package:mobile/screens/overview_screen.dart';
import 'package:mobile/screens/stock_list_screen.dart';
import 'package:mobile/screens/warehouse_selection_screen.dart';
import 'package:mobile/widgets/app_scaffold.dart';
import 'package:mobile/widgets/warehouse_selector.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._session);

  final Session _session;

  @override
  Session build() => _session;
}

class _FakeOrderRepository extends OrderRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchOrders(
    int warehouseId,
    DateTime date, {
    String? martName,
  }) async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMartList(int warehouseId) async {
    return const [];
  }
}

class _FakeStockRepository extends StockRepository {
  @override
  Future<List<StockTransaction>> fetchStockEntries({
    required int warehouseId,
    required String date,
  }) async {
    return const [];
  }
}

class _FakeDispatchRepository extends DispatchRepository {
  @override
  Future<List<dynamic>> fetchDispatches({
    required int warehouseId,
    String? dispatchDate,
    String? martName,
    int skip = 0,
    int limit = 100,
    bool hideFullyReversed = false,
  }) async {
    return const [];
  }
}

const _readySession = Session(
  state: SessionState.ready,
  warehouseId: 1,
  warehouses: [
    WarehouseAccess(id: 1, name: 'Main Warehouse', code: 'WH-1'),
  ],
);

Future<void> _pumpShellApp(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/overview',
            builder: (context, state) => const OverviewScreen(),
          ),
          GoRoute(
            path: '/stock',
            builder: (context, state) => const StockListScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/dispatch',
            builder: (context, state) => const DispatchListScreen(),
          ),
          GoRoute(
            path: '/more',
            builder: (context, state) => const MoreHubScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/order-entry',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Order Entry Placeholder')),
        ),
      ),
      GoRoute(
        path: '/stock-entry',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Stock Entry Placeholder')),
        ),
      ),
      GoRoute(
        path: '/dispatch-entry',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Dispatch Entry Placeholder')),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSessionController(_readySession)),
        orderRepositoryProvider.overrideWithValue(_FakeOrderRepository()),
        stockRepositoryProvider.overrideWithValue(_FakeStockRepository()),
        dispatchRepositoryProvider.overrideWithValue(_FakeDispatchRepository()),
        overviewSummaryProvider.overrideWith(
          (ref) async => const OverviewSummary(
            ordersToday: 4,
            dispatchesToday: 3,
            receiptsToday: 2,
            rejectionsToday: 1,
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AppScaffold shows route-driven AppBar and FAB for orders', (
    tester,
  ) async {
    await _pumpShellApp(tester, initialLocation: '/orders');

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Create Order'), findsOneWidget);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = appBar.title;
    expect(title, isA<WarehouseSelector>());
    expect((title as WarehouseSelector).screenTitle, 'Orders');

    final bottomNav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bottomNav.currentIndex, 2);
  });

  testWidgets('AppScaffold shows warehouse selector tabs and plain More title', (
    tester,
  ) async {
    await _pumpShellApp(tester, initialLocation: '/overview');
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.text('Create Order'), findsNothing);

    var appBar = tester.widget<AppBar>(find.byType(AppBar));
    var title = appBar.title;
    expect(title, isA<WarehouseSelector>());
    expect((title as WarehouseSelector).screenTitle, 'Overview');

    await _pumpShellApp(tester, initialLocation: '/more');
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.refresh),
      ),
      findsNothing,
    );
    expect(find.text('Receive Stock'), findsNothing);

    appBar = tester.widget<AppBar>(find.byType(AppBar));
    title = appBar.title;
    expect(title, isA<Text>());
    expect((title as Text).data, 'More');
  });

  testWidgets('Shell FAB push hides bottom nav and back restores orders tab', (
    tester,
  ) async {
    await _pumpShellApp(tester, initialLocation: '/orders');

    await tester.tap(find.text('Create Order'));
    await tester.pumpAndSettle();

    expect(find.text('Order Entry Placeholder'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);

    GoRouter.of(tester.element(find.text('Order Entry Placeholder'))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('Shell FAB push hides bottom nav and back restores stock tab', (
    tester,
  ) async {
    await _pumpShellApp(tester, initialLocation: '/stock');

    await tester.tap(find.text('Receive Stock'));
    await tester.pumpAndSettle();

    expect(find.text('Stock Entry Placeholder'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);

    GoRouter.of(tester.element(find.text('Stock Entry Placeholder'))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(StockListScreen), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('Dispatch FAB switches tabs without leaving shell', (
    tester,
  ) async {
    await _pumpShellApp(tester, initialLocation: '/dispatch');

    await tester.tap(find.text('Dispatch Order'));
    await tester.pumpAndSettle();

    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    final bottomNav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bottomNav.currentIndex, 2);
  });

  testWidgets('form routes redirect to warehouse selection when no warehouse is active', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(
          () => _FakeSessionController(
            const Session(
              state: SessionState.ready,
              warehouses: [
                WarehouseAccess(id: 1, name: 'Main Warehouse', code: 'WH-1'),
              ],
            ),
          ),
        ),
        overviewSummaryProvider.overrideWith(
          (ref) async => const OverviewSummary(
            ordersToday: 0,
            dispatchesToday: 0,
            receiptsToday: 0,
            rejectionsToday: 0,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/order-entry');
    await tester.pumpAndSettle();

    expect(find.byType(WarehouseSelectionScreen), findsOneWidget);
    expect(find.text('Select Warehouse'), findsOneWidget);
  });
}
