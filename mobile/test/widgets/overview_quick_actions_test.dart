import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/widgets/overview_quick_actions.dart';

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/overview',
    routes: [
      GoRoute(
        path: '/overview',
        builder: (context, state) => const Scaffold(
          body: OverviewQuickActions(),
        ),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const Scaffold(
          body: Text('Orders Screen'),
        ),
      ),
      GoRoute(
        path: '/mart-bills',
        builder: (context, state) => const Scaffold(
          body: Text('Mart Bills Screen'),
        ),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const Scaffold(
          body: Text('Inventory Screen'),
        ),
      ),
      GoRoute(
        path: '/items',
        builder: (context, state) => const Scaffold(
          body: Text('Items Screen'),
        ),
      ),
      GoRoute(
        path: '/dispatch',
        builder: (context, state) => const Scaffold(
          body: Text('Dispatch Screen'),
        ),
      ),
      GoRoute(
        path: '/rejection-list',
        builder: (context, state) => const Scaffold(
          body: Text('Rejections Screen'),
        ),
      ),
    ],
  );
}

Future<void> _pumpOverview(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: _buildRouter(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Overview quick actions render all tiles', (tester) async {
    await _pumpOverview(tester);

    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Mart Bills'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Items'), findsOneWidget);
    expect(find.text('Dispatch'), findsOneWidget);
    expect(find.text('Rejections'), findsOneWidget);
  });

  testWidgets('Overview quick action navigates to Orders', (tester) async {
    await _pumpOverview(tester);

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('Orders Screen'), findsOneWidget);
  });

  testWidgets('Overview quick action navigates to Mart Bills', (tester) async {
    await _pumpOverview(tester);

    await tester.tap(find.text('Mart Bills'));
    await tester.pumpAndSettle();

    expect(find.text('Mart Bills Screen'), findsOneWidget);
  });
}
