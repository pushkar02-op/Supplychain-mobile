import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/admin_ledger_provider.dart';
import '../ui/semantics/agro_severity.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_status_badge.dart';

class AdminInventoryHealthScreen extends ConsumerWidget {
  const AdminInventoryHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(ledgerHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Ledger Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(ledgerHealthProvider.notifier).refresh(),
          ),
        ],
      ),
      body: healthAsync.when(
        data: (data) => _buildBody(context, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, stack) => AgroErrorState.loadFailed(
              onRetry: () => ref.read(ledgerHealthProvider.notifier).refresh(),
            ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'unknown';
    final totalBatches = data['total_batches'] ?? 0;
    final driftedCount = data['drifted_batches'] ?? 0;
    final negativeCount = data['negative_stock_batches'] ?? 0;

    final isHealthy = status == 'healthy';
    final healthStatus = AgroStatusParser.fromHealthStatus(status);
    final severityStyle = AgroSeverity.fromStatus(healthStatus);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AgroSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Card
          _HealthStatusCard(
            status: status,
            isHealthy: isHealthy,
            healthStatus: healthStatus,
            severityStyle: severityStyle,
          ),
          const SizedBox(height: AgroSpacing.xl),

          // Metrics Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: AgroSpacing.lg,
            mainAxisSpacing: AgroSpacing.lg,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _HealthMetricCard(
                title: 'Total Batches',
                value: totalBatches.toString(),
                icon: Icons.inventory_2,
                status: AgroStatus.info,
              ),
              _HealthMetricCard(
                title: 'Drifted Batches',
                value: driftedCount.toString(),
                icon: Icons.compare_arrows,
                status:
                    driftedCount > 0 ? AgroStatus.critical : AgroStatus.stable,
              ),
              _HealthMetricCard(
                title: 'Negative Stock',
                value: negativeCount.toString(),
                icon: Icons.trending_down,
                status:
                    negativeCount > 0 ? AgroStatus.critical : AgroStatus.stable,
              ),
            ],
          ),

          const SizedBox(height: AgroSpacing.xxl),

          // Action Button
          if (!isHealthy)
            FilledButton.icon(
              onPressed: () => context.push('/admin/ledger/drift'),
              icon: const Icon(Icons.list_alt),
              label: const Text('View Detailed Drift Report'),
              style: FilledButton.styleFrom(
                backgroundColor: AgroColors.critical.background,
                foregroundColor: AgroColors.critical.text,
                padding: const EdgeInsets.all(AgroSpacing.lg),
              ),
            )
          else
            const Center(
              child: Text(
                'All systems nominal. No reconciliation actions required.',
                style: AgroTypography.caption,
              ),
            ),
        ],
      ),
    );
  }
}

/// Health status card displaying overall system status with semantic severity styling.
class _HealthStatusCard extends StatelessWidget {
  final String status;
  final bool isHealthy;
  final AgroStatus healthStatus;
  final AgroSeverityStyle severityStyle;

  const _HealthStatusCard({
    required this.status,
    required this.isHealthy,
    required this.healthStatus,
    required this.severityStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: severityStyle.backgroundColor,
        borderRadius: AgroShapes.cardRadius,
        border: Border.all(color: severityStyle.borderColor),
      ),
      padding: const EdgeInsets.all(AgroSpacing.xl),
      child: Column(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 48,
            color: severityStyle.iconColor,
          ),
          const SizedBox(height: AgroSpacing.lg),
          Text(
            'System Status: ${status.toUpperCase()}',
            style: AgroTypography.cardTitle.copyWith(
              fontSize: 20,
              color: severityStyle.textColor,
            ),
          ),
          const SizedBox(height: AgroSpacing.md),
          AgroStatusBadge(
            status: healthStatus,
            label: status[0].toUpperCase() + status.substring(1).toLowerCase(),
          ),
        ],
      ),
    );
  }
}

/// Metric card for displaying health metrics with semantic status styling.
class _HealthMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final AgroStatus status;

  const _HealthMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final severityStyle = AgroSeverity.fromStatus(status);

    return AgroCard.outlined(
      borderColor: severityStyle.borderColor,
      child: Padding(
        padding: const EdgeInsets.all(AgroSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: severityStyle.iconColor),
            const SizedBox(height: AgroSpacing.sm),
            Text(value, style: AgroTypography.metricValue),
            const SizedBox(height: AgroSpacing.xs),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AgroTypography.metricLabel,
            ),
          ],
        ),
      ),
    );
  }
}
