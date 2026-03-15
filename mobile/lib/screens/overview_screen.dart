import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/session/session_controller.dart';
import '../core/models/user_role.dart';
import '../providers/warehouse_dashboard_provider.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/theme/agro_colors.dart';
import '../widgets/dashboard_metric_card.dart';
import '../widgets/forecast_alert_summary.dart';
import '../widgets/inventory_signal_summary.dart';
import '../widgets/ledger_health_summary.dart';
import '../widgets/overview_quick_actions.dart';
import '../widgets/activity_timeline.dart';
import '../widgets/top_moving_items_panel.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManageUsers = ref.watch(
      sessionProvider.select((session) => session.canManageUsers),
    );
    final role = ref.watch(sessionProvider.select((session) => session.role));
    final canSeeForecast =
        role == UserRole.owner || role == UserRole.manager;
    final canSeeActivity =
        role == UserRole.owner || role == UserRole.manager;
    final todayFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final dashboardAsync = ref.watch(warehouseDashboardProvider);
    final dashboard = dashboardAsync.valueOrNull;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          final _ = await ref.refresh(warehouseDashboardProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AgroSpacing.screenPadding),
          children: [
            if (dashboardAsync.isLoading && dashboard == null)
              const Padding(
                padding: EdgeInsets.only(bottom: AgroSpacing.md),
                child: LinearProgressIndicator(),
              ),
            if (dashboardAsync.hasError && dashboard == null)
              Padding(
                padding: const EdgeInsets.only(bottom: AgroSpacing.md),
                child: Text(
                  'Failed to load dashboard: ${dashboardAsync.error}',
                  style: AgroTypography.caption.copyWith(color: Colors.red),
                ),
              ),
            Text(todayFormatted, style: AgroTypography.captionEmphasis),
            const SizedBox(height: AgroSpacing.lg),

            const OverviewQuickActions(),

            const SizedBox(height: AgroSpacing.lg),

            const Row(
              children: [
                Icon(Icons.dashboard, color: AgroColors.textSecondary, size: 18),
                SizedBox(width: AgroSpacing.sm),
                Text('Operations Today', style: AgroTypography.sectionTitle),
              ],
            ),
            const SizedBox(height: AgroSpacing.sm),
            _buildOperationsSection(context, dashboard),

            const SizedBox(height: AgroSpacing.lg),

            if (dashboard != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.inventory, color: AgroColors.textSecondary, size: 18),
                      SizedBox(width: AgroSpacing.sm),
                      Text('Inventory Health', style: AgroTypography.sectionTitle),
                    ],
                  ),
                  const SizedBox(height: AgroSpacing.sm),
                  InventorySignalSummary(
                    stable: dashboard.inventoryStable,
                    watch: dashboard.inventoryWatch,
                    critical: dashboard.inventoryCritical,
                  ),
                ],
              ),

            const SizedBox(height: AgroSpacing.lg),

            if (canSeeForecast && dashboard != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: AgroColors.textSecondary, size: 18),
                      SizedBox(width: AgroSpacing.sm),
                      Text('Forecast Alerts', style: AgroTypography.sectionTitle),
                    ],
                  ),
                  const SizedBox(height: AgroSpacing.sm),
                  ForecastAlertSummary(
                    critical: dashboard.forecastCriticalItems,
                    warning: dashboard.forecastWarningItems,
                    onTap: () => context.push('/admin/forecasting'),
                  ),
                ],
              ),

            if (canSeeForecast && dashboard != null)
              const SizedBox(height: AgroSpacing.lg),

            if (canManageUsers && dashboard != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.account_balance,
                        color: AgroColors.textSecondary,
                        size: 18,
                      ),
                      SizedBox(width: AgroSpacing.sm),
                      Text('Ledger Health', style: AgroTypography.sectionTitle),
                    ],
                  ),
                  const SizedBox(height: AgroSpacing.sm),
                  LedgerHealthSummary(
                    status: dashboard.ledgerHealthStatus,
                    driftedBatches: dashboard.driftBatchCount,
                    onTap: () => context.push('/admin/ledger/health'),
                  ),
                ],
              ),

            if (canManageUsers && dashboard != null)
              const SizedBox(height: AgroSpacing.lg),

            if (canSeeActivity) const ActivityTimeline(),

            if (canSeeActivity) const SizedBox(height: AgroSpacing.lg),

            if (canSeeActivity) const TopMovingItemsPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationsSection(
    BuildContext context,
    dynamic dashboard,
  ) {
    final orders = dashboard?.ordersToday ?? 0;
    final dispatches = dashboard?.dispatchesToday ?? 0;
    final receipts = dashboard?.receiptsToday ?? 0;
    final rejections = dashboard?.rejectionsToday ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardMetricCard(
                title: 'Orders',
                value: orders.toString(),
                icon: Icons.receipt_long,
                color: AgroColors.info.text,
                onTap: () => context.go('/orders'),
              ),
            ),
            const SizedBox(width: AgroSpacing.md),
            Expanded(
              child: DashboardMetricCard(
                title: 'Dispatches',
                value: dispatches.toString(),
                icon: Icons.local_shipping,
                color: AgroColors.warning.text,
                onTap: () => context.go('/dispatch'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AgroSpacing.md),
        Row(
          children: [
            Expanded(
              child: DashboardMetricCard(
                title: 'Receipts',
                value: receipts.toString(),
                icon: Icons.inventory_2,
                color: AgroColors.success.text,
                onTap: () => context.go('/stock'),
              ),
            ),
            const SizedBox(width: AgroSpacing.md),
            Expanded(
              child: DashboardMetricCard(
                title: 'Rejections',
                value: rejections.toString(),
                icon: Icons.cancel_outlined,
                color: AgroColors.caution.text,
                onTap: () => context.push('/rejection-list'),
              ),
            ),
          ],
        ),
      ],
    );
  }

}
