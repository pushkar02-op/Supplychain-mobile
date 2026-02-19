import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/admin_ledger_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dispatch_provider.dart';
import '../providers/order_provider.dart';
import '../services/stock_service.dart';
import '../ui/semantics/agro_severity.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_decision_card.dart';
import '../ui/widgets/agro_error_state.dart';

/// Overview screen - read-only dashboard showing today's system snapshot.
/// This is Tab 1 in the bottom navigation.
class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  bool _loading = true;
  String? _error;

  int _ordersToday = 0;
  int _dispatchesToday = 0;
  int _stockEntriesToday = 0;

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  Future<void> _loadTodayData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final results = await Future.wait([
        ref.read(orderListProvider.notifier).fetchOrdersForDate(DateTime.now()),
        ref
            .read(dispatchListProvider.notifier)
            .fetchDispatchesForDate(DateTime.now()),
        StockService.fetchStockEntries(date: todayStr),
      ]);

      if (!mounted) return;
      setState(() {
        _ordersToday = results[0].length;
        _dispatchesToday = results[1].length;
        _stockEntriesToday = results[2].length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.value?.isAdmin ?? false;
    final todayFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());

    // Watch ledger health for the decision strip (available to all users)
    final healthAsync = ref.watch(ledgerHealthProvider);

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Overview'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodayData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? AgroErrorState.loadFailed(
                customTitle: 'Could not load overview',
                onRetry: _loadTodayData,
              )
              : RefreshIndicator(
                onRefresh: _loadTodayData,
                child: ListView(
                  padding: const EdgeInsets.all(AgroSpacing.screenPadding),
                  children: [
                    // Decision Strip (Available to all users if data exists)
                    if (healthAsync.hasValue && healthAsync.value != null)
                      _buildDecisionStrip(healthAsync.value!),

                    // Date Header
                    Text(todayFormatted, style: AgroTypography.captionEmphasis),
                    const SizedBox(height: AgroSpacing.lg),

                    // Today's Operations
                    const Text(
                      "Today's Operations",
                      style: AgroTypography.sectionTitle,
                    ),
                    const SizedBox(height: AgroSpacing.sm),
                    _buildOperationsGrid(),
                    const SizedBox(height: AgroSpacing.xl),

                    // Quick Actions
                    const Text('Quick Actions', style: AgroTypography.sectionTitle),
                    const SizedBox(height: AgroSpacing.sm),
                    _buildQuickActions(),

                    // Admin Summary (Admin only)
                    if (isAdmin) ...[
                      const SizedBox(height: AgroSpacing.xl),
                      const Text('System Health', style: AgroTypography.sectionTitle),
                      const SizedBox(height: AgroSpacing.sm),
                      _buildAdminSummary(),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _buildDecisionStrip(Map<String, dynamic> data) {
    // FIX 1: Use combined signals (only Ledger available currently)
    final statusStr = data['status'] as String? ?? 'unknown';
    final agroStatus = AgroStatusParser.fromHealthStatus(statusStr);
    final driftCount = data['drifted_batches'] ?? 0;

    String primary;
    String? secondary;
    String explanation;

    // FIX 4: Adjust Explanation Copy (Truthful, Not Absolute)
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

    // FIX 3: Correct Source Attribution ("Ledger Health" since only using ledger)
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

  Widget _buildOperationsGrid() {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Orders',
            value: _ordersToday.toString(),
            icon: Icons.receipt_long,
            color: Colors.blue,
            onTap: () => context.push('/orders'),
          ),
        ),
        const SizedBox(width: AgroSpacing.md),
        Expanded(
          child: _MetricCard(
            label: 'Dispatches',
            value: _dispatchesToday.toString(),
            icon: Icons.local_shipping,
            color: Colors.orange,
            onTap: () => context.push('/dispatch-entries'),
          ),
        ),
        const SizedBox(width: AgroSpacing.md),
        Expanded(
          child: _MetricCard(
            label: 'Stock In',
            value: _stockEntriesToday.toString(),
            icon: Icons.inventory_2,
            color: Colors.green,
            onTap: () => context.push('/stock-list'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
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

  Widget _buildAdminSummary() {
    final healthAsync = ref.watch(ledgerHealthProvider);

    return healthAsync.when(
      loading:
          () => const AgroCard(
            child: Padding(
              padding: EdgeInsets.all(AgroSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      error: (e, _) {
        final severity = AgroSeverity.fromStatus(AgroStatus.critical);
        return AgroCard(
          borderColor: severity.borderColor,
          child: ListTile(
            leading: Icon(Icons.error_outline, color: severity.iconColor),
            title: const Text('Could not load health'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed:
                  () => ref.read(ledgerHealthProvider.notifier).refresh(),
            ),
          ),
        );
      },
      data: (data) {
        final status = data['status'] as String? ?? 'unknown';
        final agroStatus = AgroStatusParser.fromHealthStatus(status);
        final severity = AgroSeverity.fromStatus(agroStatus);
        final isHealthy = status == 'healthy';
        final driftedBatches = data['drifted_batches'] ?? 0;
        final negativeStock = data['negative_stock_batches'] ?? 0;

        return AgroCard.outlined(
          borderColor: severity.borderColor,
          onTap: () => context.push('/admin/ledger/health'),
          child: Row(
            children: [
              Icon(severity.icon, color: severity.iconColor, size: 32),
              const SizedBox(width: AgroSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHealthy ? 'System Healthy' : 'Attention Needed',
                      style: AgroTypography.emphasis.copyWith(
                        color: severity.textColor,
                      ),
                    ),
                    if (!isHealthy)
                      Text(
                        'Drift: $driftedBatches | Negative: $negativeStock',
                        style: AgroTypography.caption,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AgroColors.textDisabled),
            ],
          ),
        );
      },
    );
  }
}

/// Metric card widget for the operations grid.
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AgroCard.outlined(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AgroSpacing.sm),
          Text(value, style: AgroTypography.metricValue.copyWith(color: color)),
          const SizedBox(height: AgroSpacing.xs),
          Text(label, style: AgroTypography.metricLabel),
        ],
      ),
    );
  }
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
