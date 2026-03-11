import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/session/session_controller.dart';
import '../models/order.dart';
import '../providers/overview_provider.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_decision_card.dart';
import '../ui/widgets/agro_status_badge.dart';
import '../widgets/warehouse_selector.dart';

/// Overview screen - read-only dashboard showing today's system snapshot.
/// This is Tab 1 in the bottom navigation.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  Future<void> _refreshOverview(WidgetRef ref) async {
    ref.invalidate(overviewSummaryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManageUsers = ref.watch(
      sessionProvider.select((session) => session.canManageUsers),
    );
    final todayFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final summaryAsync = ref.watch(overviewSummaryProvider);
    final summary = summaryAsync.valueOrNull;

    final healthData = summary?.ledgerHealth;
    final orders = _deriveOrdersActivity(summary?.orders ?? const <Order>[]);
    final dispatches = _placeholderActivity(
      label: 'Dispatches Today',
      icon: Icons.local_shipping,
      semanticColor: AgroColors.warning,
      caption: 'Open Dispatch to load',
    );
    final receipts = _placeholderActivity(
      label: 'Receipts Today',
      icon: Icons.inventory_2,
      semanticColor: AgroColors.success,
      caption: 'Open Stock to load',
    );
    final rejections = _placeholderActivity(
      label: 'Rejections Today',
      icon: Icons.cancel_outlined,
      semanticColor: AgroColors.caution,
      caption: 'Open Rejections to load',
    );
    final alerts = _deriveAlerts(
      canManageUsers: canManageUsers,
      ledgerData: healthData,
    );

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const WarehouseSelector(screenTitle: 'Overview'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 1,
        toolbarHeight: 72,
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
            if (summaryAsync.isLoading && summary == null)
              const Padding(
                padding: EdgeInsets.only(bottom: AgroSpacing.md),
                child: LinearProgressIndicator(),
              ),
            if (summaryAsync.hasError && summary == null)
              Padding(
                padding: const EdgeInsets.only(bottom: AgroSpacing.md),
                child: Text(
                  'Failed to load overview summary: ${summaryAsync.error}',
                  style: AgroTypography.caption.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),
            if (healthData != null) _buildDecisionStrip(healthData),

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
            _buildAlertsAndHealth(
              context,
              alerts,
              canManageUsers: canManageUsers,
            ),

            const SizedBox(height: AgroSpacing.xl),

            const Text('Quick Actions', style: AgroTypography.sectionTitle),
            const SizedBox(height: AgroSpacing.sm),
            _buildQuickActions(context),
          ],
        ),
      ),
    );
  }

  _ActivityCardData _placeholderActivity({
    required String label,
    required IconData icon,
    required AgroSemanticColor semanticColor,
    required String caption,
  }) {
    return _ActivityCardData(
      label: label,
      value: '--',
      icon: icon,
      semanticColor: semanticColor,
      subtext: [caption],
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
    required bool canManageUsers,
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
            canManageUsers
                ? 'No governance alerts'
                : 'No active operator alerts',
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

  _ActivityCardData _deriveOrdersActivity(List<Order> orders) {
    final total = orders.length;
    // Status is just a placeholder for now since we don't have dispatch info in simple Order model
    final pending =
        orders.where((o) => o.status.toLowerCase().contains('pending')).length;

    final subtext = <String>['$pending pending'];

    return _ActivityCardData(
      label: 'Orders Today',
      value: '$total',
      icon: Icons.receipt_long,
      semanticColor: AgroColors.info,
      subtext: subtext,
    );
  }

  List<_AlertRowData> _deriveAlerts({
    required bool canManageUsers,
    required Map<String, dynamic>? ledgerData,
  }) {
    final driftedBatches =
        (ledgerData?['drifted_batches'] as num?)?.toInt() ?? 0;
    final ledgerStatus = (ledgerData?['status'] ?? '').toString().toLowerCase();
    final reconciliationNeeded =
        (ledgerStatus == 'unhealthy' || driftedBatches > 0) ? 1 : 0;

    final alerts = <_AlertRowData>[];

    if (canManageUsers) {
      if (driftedBatches > 0) {
        alerts.add(
          _AlertRowData(
            status: AgroStatus.major,
            badgeLabel: 'Drift',
            title: 'Drift Count: $driftedBatches',
            route: '/admin/ledger/health',
          ),
        );
      }
      if (reconciliationNeeded > 0) {
        alerts.add(
          _AlertRowData(
            status: AgroStatus.minor,
            badgeLabel: 'Recon',
            title: 'Reconciliation Needed: $driftedBatches',
            route: '/admin/ledger/health',
          ),
        );
      }
      return alerts;
    }
    if (reconciliationNeeded > 0) {
      alerts.add(
        const _AlertRowData(
          status: AgroStatus.minor,
          badgeLabel: 'Recon',
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
