import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/top_moving_item.dart';
import 'package:mobile/providers/top_moving_items_provider.dart';
import 'package:mobile/widgets/top_moving_items_panel.dart';

Future<void> _pumpPanel(
  WidgetTester tester, {
  required List<TopMovingItem> items,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        topMovingItemsProvider.overrideWith((ref) async => items),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: TopMovingItemsPanel(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders empty state when no items', (tester) async {
    await _pumpPanel(tester, items: const []);
    expect(find.text('No movement today'), findsOneWidget);
  });

  testWidgets('renders top moving items list', (tester) async {
    await _pumpPanel(
      tester,
      items: const [
        TopMovingItem(itemId: 1, itemName: 'Item A', totalOut: 12.5),
        TopMovingItem(itemId: 2, itemName: 'Item B', totalOut: 8),
      ],
    );

    expect(find.text('Item A'), findsOneWidget);
    expect(find.text('Item B'), findsOneWidget);
    expect(find.text('12.50'), findsOneWidget);
    expect(find.text('8.00'), findsOneWidget);
  });
}
