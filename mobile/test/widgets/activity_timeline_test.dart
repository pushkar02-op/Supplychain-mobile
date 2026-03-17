import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/models/audit_log_entry.dart';
import 'package:mobile/providers/audit_provider.dart';
import 'package:mobile/widgets/activity_timeline.dart';
import 'package:mobile/widgets/activity_timeline_item.dart';

final _sampleLogs = List.generate(
  6,
  (index) => AuditLogEntry(
    id: index + 1,
    action: 'order_created',
    actorUserId: 99,
    entityType: 'Order',
    entityId: index + 10,
    warehouseId: 1,
    eventMetadata: const {'source': 'test'},
    createdAt: DateTime.utc(2024, 1, 1, 10, index),
  ),
);

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/overview',
    routes: [
      GoRoute(
        path: '/overview',
        builder: (context, state) => const Scaffold(
          body: ActivityTimeline(),
        ),
      ),
      GoRoute(
        path: '/admin/audit',
        builder: (context, state) => const Scaffold(
          body: Text('Audit Screen'),
        ),
      ),
    ],
  );
}

Future<void> _pumpTimeline(
  WidgetTester tester, {
  required List<AuditLogEntry> logs,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recentActivityProvider.overrideWith((ref) async => logs),
      ],
      child: MaterialApp.router(routerConfig: _buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('timeline renders and limits to 5 items', (tester) async {
    await _pumpTimeline(tester, logs: _sampleLogs);

    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.byType(ActivityTimelineItem), findsNWidgets(5));
  });

  testWidgets('View All navigates to audit screen', (tester) async {
    await _pumpTimeline(tester, logs: _sampleLogs);

    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();

    expect(find.text('Audit Screen'), findsOneWidget);
  });
}
