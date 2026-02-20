import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/admin_ledger_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dispatch_provider.dart';
import '../providers/forecasting_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/mart_bill_provider.dart';
import '../providers/order_provider.dart';
import '../providers/rejection_provider.dart';
import '../providers/stock_list_provider.dart';
import '../services/forecasting_service.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_decision_card.dart';
import '../ui/widgets/agro_status_badge.dart';

/// Overview screen - read-only dashboard showing today's system snapshot.
/// This is Tab 1 in the bottom navigation.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  Future<void> _refreshOverview(WidgetRef ref) async {
    ref.invalidate(orderListProvider);
    ref.invalidate(dispatchListProvider);
    ref.invalidate(stockListProvider);
    ref.invalidate(rejectionListProvider);
    ref.invalidate(inventoryListProvider);
    ref.invalidate(martBillProvider);
    ref.invalidate(forecastingProvider);
    ref.invalidate(ledgerHealthProvider);
    ref.invalidate(driftReportProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(authProvider).value?.isAdmin ?? false;
    final todayFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());

    final healthAsync = ref.watch(ledgerHealthProvider);
    final ordersAsync = ref.watch(orderListProvider);
    final dispatchAsync = ref.watch(dispatchListProvider);
    final stockAsync = ref.watch(stockListProvider);
    final rejectionAsync = ref.watch(rejectionListProvider);
    final inventoryAsync = ref.watch(inventoryListProvider);
    final martBillAsync = ref.watch(martBillProvider);
    final forecastAsync = ref.watch(forecastingProvider);
    final driftAsync = ref.watch(driftReportProvider);

    final orders = _deriveOrdersActivity(ordersAsync);
    final dispatches = _deriveDispatchActivity(dispatchAsync);
    final receipts = _deriveReceiptsActivity(stockAsync);
    final rejections = _deriveRejectionsActivity(rejectionAsync);

    final alerts = _deriveAlerts(
      isAdmin: isAdmin,
      inventoryAsync: inventoryAsync,
      martBillAsync: martBillAsync,
      forecastAsync: forecastAsync,
      healthAsync: healthAsync,
      driftAsync: driftAsync,
    );

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Overview'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 1,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshOverview(ref),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshOverview(ref),
        child: ListView(
          padding: const EdgeInsets.all(AgroSpacing.screenPadding),
          children: [
            if (healthAsync.hasValue && healthAsync.value != null)
              _buildDecisionStrip(healthAsync.value!),

            Text(todayFormatted, style: AgroTypography.captionEmphasis),
            const SizedBox(height: AgroSpacing.lg),

            const Text("Today's Activity", style: AgroTypography.sectionTitle),
            const SizedBox(height: AgroSpacing.sm),
            _buildTodayActivity(
              context,
              orders,
              dispatches,
              receipts,
              rejections,
            ),

            const SizedBox(height: AgroSpacing.xl),

            const Text('Alerts & Health', style: AgroTypography.sectionTitle),
            const SizedBox(height: AgroSpacing.sm),
            _buildAlertsAndHealth(context, alerts, isAdmin: isAdmin),

            const SizedBox(height: AgroSpacing.xl),

            const Text('Quick Actions', style: AgroTypography.sectionTitle),
            const SizedBox(height: AgroSpacing.sm),
            _buildQuickActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionStrip(Map<String, dynamic> data) {
    final statusStr = data['status'] as String? ?? 'unknown';
    final agroStatus = AgroStatusParser.fromHealthStatus(statusStr);
    final driftCount = data['drifted_batches'] ?? 0;

    String primary;
    String? secondary;
    String explanation;

    if (agroStatus == AgroStatus.stable) {
      primary = 'Ledger Balanced';
      explanation = 'No ledger drift detected based on current records.';
    } else {
      primary = 'Inventory Drift Detected';
      secondary =
          '$driftCount batch${driftCount == 1 ? '' : 'es'} showing discrepancies';
      explanation =
          'Differences found between ledger and physical stock calculations.';
    }

    const source = 'Ledger Health';

    return Padding(
      padding: const EdgeInsets.only(bottom: AgroSpacing.lg),
      child: AgroDecisionCard(
        status: agroStatus,
        primaryMessage: primary,
        secondaryMessage: secondary,
        explanation: explanation,
        source: source,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  Widget _buildTodayActivity(
    BuildContext context,
    _ActivityCardData orders,
    _ActivityCardData dispatches,
    _ActivityCardData receipts,
    _ActivityCardData rejections,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActivityCard(
                data: orders,
                onTap: () => context.push('/orders'),
              ),
            ),
            const SizedBox(width: AgroSpacing.md),
            Expanded(
              child: _ActivityCard(
                data: dispatches,
                onTap: () => context.push('/dispatch-entries'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AgroSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ActivityCard(
                data: receipts,
                onTap: () => context.push('/stock-list'),
              ),
            ),
            const SizedBox(width: AgroSpacing.md),
            Expanded(
              child: _ActivityCard(
                data: rejections,
                onTap: () => context.push('/rejection-list'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertsAndHealth(
    BuildContext context,
    List<_AlertRowData> alerts, {
    required bool isAdmin,
  }) {
    if (alerts.isEmpty) {
      return AgroCard.outlined(
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const AgroStatusBadge.compact(
            status: AgroStatus.stable,
            label: 'System Healthy',
          ),
          title: Text(
            isAdmin ? 'No governance alerts' : 'No active operator alerts',
            style: AgroTypography.caption,
          ),
        ),
      );
    }

    return Column(
      children:
          alerts
              .map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: AgroSpacing.sm),
                  child: AgroCard.outlined(
                    onTap:
                        a.route == null ? null : () => context.push(a.route!),
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: AgroStatusBadge.compact(
                        status: a.status,
                        label: a.badgeLabel,
                      ),
                      title: Text(
                        a.title,
                        style: AgroTypography.captionEmphasis,
                      ),
                      subtitle:
                          a.subtitle == null
                              ? null
                              : Text(
                                a.subtitle!,
                                style: AgroTypography.caption,
                              ),
                      trailing:
                          a.route == null
                              ? null
                              : const Icon(
                                Icons.chevron_right,
                                color: AgroColors.textDisabled,
                              ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: AgroSpacing.sm,
      runSpacing: AgroSpacing.sm,
      children: [
        _ActionChip(
          label: 'New Stock',
          icon: Icons.add_box_outlined,
          onTap: () => context.push('/stock-entry'),
        ),
        _ActionChip(
          label: 'New Order',
          icon: Icons.add_shopping_cart,
          onTap: () => context.push('/order-entry'),
        ),
        _ActionChip(
          label: 'View Inventory',
          icon: Icons.analytics_outlined,
          onTap: () => context.push('/inventory'),
        ),
        _ActionChip(
          label: 'Mart Bills',
          icon: Icons.receipt_outlined,
          onTap: () => context.push('/mart-bills'),
        ),
      ],
    );
  }

  _ActivityCardData _deriveOrdersActivity(
    AsyncValue<OrderListState> ordersAsync,
  ) {
    final orders =
        ordersAsync.valueOrNull?.orders ?? const <Map<String, dynamic>>[];
    final total = orders.length;
    final pending =
        orders.where((o) {
          final dispatched = (o['quantity_dispatched'] as num?) ?? 0;
          return dispatched == 0;
        }).length;
    final partial =
        orders.where((o) {
          final ordered = (o['quantity_ordered'] as num?) ?? 0;
          final dispatched = (o['quantity_dispatched'] as num?) ?? 0;
          return dispatched > 0 && dispatched < ordered;
        }).length;
    final reversed =
        orders.where((o) {
          final s = (o['status'] ?? '').toString().toLowerCase();
          return s.contains('reversed');
        }).length;

    final subtext = <String>[
      '$pending pending',
      '$partial partially fulfilled',
      if (reversed > 0) '$reversed reversed',
    ];

    return _ActivityCardData(
      label: 'Orders Today',
      value: '$total',
      icon: Icons.receipt_long,
      semanticColor: AgroColors.info,
      subtext: subtext,
    );
  }

  _ActivityCardData _deriveDispatchActivity(
    AsyncValue<DispatchListState> dispatchAsync,
  ) {
    final dispatches =
        dispatchAsync.valueOrNull?.dispatches ?? const <dynamic>[];
    final total = dispatches.length;

    final partial =
        dispatches.where((d) {
          final map = d as Map<String, dynamic>;
          return (map['status'] as String?) == 'Partially Reversed';
        }).length;
    final reversed =
        dispatches.where((d) {
          final map = d as Map<String, dynamic>;
          return (map['status'] as String?) == 'Reversed';
        }).length;

    return _ActivityCardData(
      label: 'Dispatches Today',
      value: '$total',
      icon: Icons.local_shipping,
      semanticColor: AgroColors.warning,
      subtext: ['$partial partial', if (reversed > 0) '$reversed reversed'],
    );
  }

  _ActivityCardData _deriveReceiptsActivity(
    AsyncValue<List<dynamic>> stockAsync,
  ) {
    final entries = stockAsync.valueOrNull ?? const <dynamic>[];
    final total = entries.length;

    int adjusted = 0;
    int adjustments = 0;
    for (final e in entries) {
      final entry = e as Map<String, dynamic>;
      final qty = (entry['quantity'] as num?)?.toDouble() ?? 0;
      final batchQty = (entry['batch_quantity'] as num?)?.toDouble() ?? qty;
      final isAdjusted = (batchQty - qty).abs() > 0.001;
      if (!isAdjusted) continue;
      adjusted += 1;

      final typeFields = [
        entry['entry_type'],
        entry['mode'],
        entry['adjustment_type'],
        entry['reason'],
      ];
      final looksAdjustment = typeFields.whereType<String>().any(
        (v) => v.toLowerCase().contains('adjust'),
      );
      if (looksAdjustment) {
        adjustments += 1;
      }
    }
    final corrections = adjusted - adjustments;

    return _ActivityCardData(
      label: 'Receipts Today',
      value: '$total',
      icon: Icons.inventory_2,
      semanticColor: AgroColors.success,
      subtext: [
        '$corrections corrections',
        '$adjustments adjustment${adjustments == 1 ? '' : 's'}',
      ],
    );
  }

  _ActivityCardData _deriveRejectionsActivity(
    AsyncValue<RejectionListState> rejectionAsync,
  ) {
    final items =
        rejectionAsync.valueOrNull?.items ?? const <Map<String, dynamic>>[];
    final total = items.length;
    final reversed =
        items.where((r) => (r['is_active'] ?? true) == false).length;

    return _ActivityCardData(
      label: 'Rejections Today',
      value: '$total',
      icon: Icons.cancel_outlined,
      semanticColor: AgroColors.caution,
      subtext: ['$reversed reversed'],
    );
  }

  List<_AlertRowData> _deriveAlerts({
    required bool isAdmin,
    required AsyncValue<InventoryState> inventoryAsync,
    required AsyncValue<MartBillState> martBillAsync,
    required AsyncValue<List<ItemForecast>> forecastAsync,
    required AsyncValue<Map<String, dynamic>> healthAsync,
    required AsyncValue<List<dynamic>> driftAsync,
  }) {
    final inventoryItems =
        inventoryAsync.valueOrNull?.items ?? const <Map<String, dynamic>>[];
    final severeInventory =
        inventoryItems.where((i) {
          final sev = (i['severity'] ?? '').toString().toUpperCase();
          return sev == 'CRITICAL';
        }).length;
    final minorInventory =
        inventoryItems.where((i) {
          final sev = (i['severity'] ?? '').toString().toUpperCase();
          final status = (i['status'] ?? '').toString().toUpperCase();
          return status != 'HEALTHY' && sev != 'CRITICAL';
        }).length;

    final bills =
        martBillAsync.valueOrNull?.bills ?? const <Map<String, dynamic>>[];
    final unverifiedBills =
        bills.where((b) {
          final status =
              (b['status'] ?? 'NEEDS_REVIEW').toString().toUpperCase();
          return status != 'VERIFIED';
        }).length;

    final forecasts = forecastAsync.valueOrNull ?? const <ItemForecast>[];
    final forecastAnomalies =
        forecasts.where((f) {
          final signal = f.signal.toUpperCase();
          return signal != 'STABLE';
        }).length;

    final ledger = healthAsync.valueOrNull;
    final driftedBatches = (ledger?['drifted_batches'] as num?)?.toInt() ?? 0;
    final ledgerStatus = (ledger?['status'] ?? '').toString().toLowerCase();
    final reconciliationNeeded =
        (ledgerStatus == 'unhealthy' || driftedBatches > 0) ? 1 : 0;

    final driftRows = driftAsync.valueOrNull ?? const <dynamic>[];
    final severeDrift =
        driftRows.where((d) {
          final row = d as Map<String, dynamic>;
          final sev = (row['severity'] ?? '').toString().toUpperCase();
          return sev == 'CRITICAL';
        }).length;

    final alerts = <_AlertRowData>[];

    if (isAdmin) {
      if (driftedBatches > 0) {
        alerts.add(
          _AlertRowData(
            status: AgroStatus.major,
            badgeLabel: 'DRIFT',
            title: 'Drift Count: $driftedBatches',
            route: '/admin/ledger/health',
          ),
        );
      }
      if (severeDrift > 0) {
        alerts.add(
          _AlertRowData(
            status: AgroStatus.critical,
            badgeLabel: 'SEVERE',
            title: 'Severe Drift Count: $severeDrift',
            route: '/admin/ledger/health',
          ),
        );
      }
      if (unverifiedBills > 0) {
        alerts.add(
          _AlertRowData(
            status: AgroStatus.major,
            badgeLabel: 'VERIFY',
            title: 'Unverified Mart Bills: $unverifiedBills',
            route: '/mart-bills',
          ),
        );
      }
      if (forecastAnomalies > 0) {
        alerts.add(
          _AlertRowData(
            status: AgroStatus.info,
            badgeLabel: 'FORECAST',
            title: 'Forecast Anomalies: $forecastAnomalies',
            route: '/items',
          ),
        );
      }
      if (reconciliationNeeded > 0) {
        alerts.add(
          _AlertRowData(
            status: AgroStatus.minor,
            badgeLabel: 'RECON',
            title: 'Reconciliation Needed: $driftedBatches',
            route: '/admin/ledger/health',
          ),
        );
      }
      return alerts;
    }

    if (severeInventory > 0) {
      alerts.add(
        _AlertRowData(
          status: AgroStatus.critical,
          badgeLabel: 'CRITICAL',
          title:
              '$severeInventory Inventory Issue${severeInventory == 1 ? '' : 's'}',
          route: '/inventory',
        ),
      );
    }
    if (unverifiedBills > 0) {
      alerts.add(
        _AlertRowData(
          status: AgroStatus.major,
          badgeLabel: 'VERIFY',
          title:
              '$unverifiedBills Unverified Mart Bill${unverifiedBills == 1 ? '' : 's'}',
          route: '/mart-bills',
        ),
      );
    }
    if (forecastAnomalies > 0) {
      alerts.add(
        _AlertRowData(
          status: AgroStatus.info,
          badgeLabel: 'FORECAST',
          title:
              '$forecastAnomalies Forecast Anomal${forecastAnomalies == 1 ? 'y' : 'ies'}',
          route: '/items',
        ),
      );
    }
    if (minorInventory > 0) {
      alerts.add(
        _AlertRowData(
          status: AgroStatus.minor,
          badgeLabel: 'DRIFT',
          title: '$minorInventory Minor Drift',
          route: '/inventory',
        ),
      );
    }
    if (reconciliationNeeded > 0) {
      alerts.add(
        const _AlertRowData(
          status: AgroStatus.minor,
          badgeLabel: 'RECON',
          title: 'Reconciliation Pending',
          subtitle: 'Ledger indicates drifted batches',
          route: '/inventory',
        ),
      );
    }

    return alerts;
  }
}

class _ActivityCardData {
  final String label;
  final String value;
  final IconData icon;
  final AgroSemanticColor semanticColor;
  final List<String> subtext;

  const _ActivityCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.semanticColor,
    required this.subtext,
  });
}

class _ActivityCard extends StatelessWidget {
  final _ActivityCardData data;
  final VoidCallback onTap;

  const _ActivityCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AgroCard.outlined(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.semanticColor.text, size: 24),
          const SizedBox(height: AgroSpacing.sm),
          Text(
            data.value,
            style: AgroTypography.metricValue.copyWith(
              color: data.semanticColor.text,
            ),
          ),
          const SizedBox(height: AgroSpacing.xs),
          Text(data.label, style: AgroTypography.metricLabel),
          const SizedBox(height: AgroSpacing.xs),
          ...data.subtext.map(
            (line) => Text(line, style: AgroTypography.caption),
          ),
        ],
      ),
    );
  }
}

class _AlertRowData {
  final AgroStatus status;
  final String badgeLabel;
  final String title;
  final String? subtitle;
  final String? route;

  const _AlertRowData({
    required this.status,
    required this.badgeLabel,
    required this.title,
    this.subtitle,
    this.route,
  });
}

/// Action chip widget for quick actions.
class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AgroColors.primary),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AgroColors.surface,
      side: const BorderSide(color: AgroColors.divider),
    );
  }
}
