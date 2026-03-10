import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_ledger_provider.dart';
import '../ui/semantics/agro_severity.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_key_value_row.dart';
import '../ui/widgets/agro_section.dart';
import '../ui/widgets/agro_status_badge.dart';

class AdminReconciliationDetailScreen extends ConsumerWidget {
  final int itemId;
  final String itemName;

  const AdminReconciliationDetailScreen({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(reconciliationDetailProvider(itemId));

    return Scaffold(
      appBar: AppBar(title: Text(itemName)),
      body: detailAsync.when(
        data: (data) => _buildBody(data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, stack) => AgroErrorState.loadFailed(
              onRetry:
                  () => ref.invalidate(reconciliationDetailProvider(itemId)),
            ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const AgroEmptyState(
        icon: Icons.analytics_outlined,
        title: 'No reconciliation data available',
        message: 'There is no reconciliation context for this item yet.',
      );
    }

    final item =
        (data['item'] is Map) ? Map<String, dynamic>.from(data['item']) : null;
    final stateQty = (data['state_qty'] as num?)?.toDouble() ?? 0.0;
    final ledgerQty = (data['ledger_qty'] as num?)?.toDouble() ?? 0.0;
    final drift = (data['drift'] as num?)?.toDouble() ?? 0.0;
    final severity = data['severity'] as String? ?? 'NONE';
    final txns = data['recent_transactions'] as List<dynamic>? ?? [];
    final batches = data['batch_snapshot'] as List<dynamic>? ?? [];
    final unit = item?['unit'] ?? '';

    // Derive semantic status and severity styling
    final status = AgroStatusParser.fromDriftSeverity(severity);
    final severityStyle = AgroSeverity.fromStatus(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AgroSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          _SummaryCard(
            stateQty: stateQty,
            ledgerQty: ledgerQty,
            drift: drift,
            unit: unit,
            status: status,
            severity: severity,
            severityStyle: severityStyle,
          ),
          const SizedBox(height: AgroSpacing.xl),

          // Batch Snapshot Section
          AgroSection(
            title: 'Batch Snapshot (Available)',
            child:
                batches.isEmpty
                    ? const Text(
                      'No active batches found.',
                      style: AgroTypography.caption,
                    )
                    : Column(
                      children:
                          batches.map((b) {
                            return _BatchCard(batch: b, unit: unit);
                          }).toList(),
                    ),
          ),

          const SizedBox(height: AgroSpacing.xl),

          // Recent Transactions Section
          AgroSection(
            title: 'Recent Transactions (Ledger)',
            child:
                txns.isEmpty
                    ? const Text(
                      'No transactions found.',
                      style: AgroTypography.caption,
                    )
                    : Column(
                      children:
                          txns.map((t) {
                            return _TransactionCard(transaction: t, unit: unit);
                          }).toList(),
                    ),
          ),
        ],
      ),
    );
  }
}

/// Summary card displaying reconciliation overview with severity-based styling.
class _SummaryCard extends StatelessWidget {
  final double stateQty;
  final double ledgerQty;
  final double drift;
  final String unit;
  final AgroStatus status;
  final String severity;
  final AgroSeverityStyle severityStyle;

  const _SummaryCard({
    required this.stateQty,
    required this.ledgerQty,
    required this.drift,
    required this.unit,
    required this.status,
    required this.severity,
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
      padding: const EdgeInsets.all(AgroSpacing.lg),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AgroStatusBadge(
              status: status,
              label: _toTitleCase(severity),
            ),
          ),
          const SizedBox(height: AgroSpacing.sm),
          AgroKeyValueRow(label: 'State (Batches)', value: '$stateQty $unit'),
          const SizedBox(height: AgroSpacing.sm),
          AgroKeyValueRow(
            label: 'Ledger (Transactions)',
            value: '$ledgerQty $unit',
          ),
          const Divider(color: AgroColors.divider),
          AgroKeyValueRow(
            label: 'Net Drift',
            value: '${drift > 0 ? "+" : ""}$drift $unit',
            emphasis: AgroKeyValueEmphasis.emphasis,
            status: AgroStatusParser.fromDriftSeverity(
              drift.abs() > 0 ? 'MAJOR' : 'NONE',
            ),
          ),
        ],
      ),
    );
  }
}

String _toTitleCase(String value) {
  return value
      .toLowerCase()
      .split('_')
      .map((part) {
        if (part.isEmpty) return part;
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

/// Card displaying a single batch in the snapshot.
class _BatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  final String unit;

  const _BatchCard({required this.batch, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AgroSpacing.sm),
      child: AgroCard.outlined(
        padding: EdgeInsets.zero,
        child: ListTile(
          dense: true,
          title: Text(
            'Batch #${batch['batch_id']}',
            style: AgroTypography.cardTitle,
          ),
          subtitle: Text(
            'Received: ${batch['received_at']}',
            style: AgroTypography.caption,
          ),
          trailing: Text(
            '${batch['qty']} $unit',
            style: AgroTypography.emphasis,
          ),
        ),
      ),
    );
  }
}

/// Card displaying a single transaction entry.
class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String unit;

  const _TransactionCard({required this.transaction, required this.unit});

  @override
  Widget build(BuildContext context) {
    final isOut = transaction['type'] == 'OUT';

    return Padding(
      padding: const EdgeInsets.only(bottom: AgroSpacing.sm),
      child: AgroCard.outlined(
        padding: EdgeInsets.zero,
        child: ListTile(
          dense: true,
          leading: Icon(
            isOut ? Icons.arrow_upward : Icons.arrow_downward,
            color: isOut ? AgroColors.critical.text : AgroColors.success.text,
            size: 16,
          ),
          title: Text(
            '${transaction['type']} - ${transaction['ref']}',
            style: AgroTypography.cardTitle,
          ),
          subtitle: Text(
            transaction['created_at'],
            style: AgroTypography.caption,
          ),
          trailing: Text(
            '${transaction['qty']} $unit',
            style: AgroTypography.emphasis,
          ),
        ),
      ),
    );
  }
}
