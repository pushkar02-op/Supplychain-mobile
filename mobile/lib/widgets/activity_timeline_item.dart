import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/audit_log_entry.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';

class ActivityTimelineItem extends StatelessWidget {
  final AuditLogEntry log;

  const ActivityTimelineItem({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final icon = _iconForAction(log.action);
    final description = _descriptionFor(log);
    final timestamp = DateFormat('MMM d, HH:mm').format(log.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AgroSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AgroColors.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(color: AgroColors.divider),
            ),
            child: Icon(icon, size: 16, color: AgroColors.textSecondary),
          ),
          const SizedBox(width: AgroSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: AgroTypography.captionEmphasis),
                const SizedBox(height: AgroSpacing.xs),
                Text(timestamp, style: AgroTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForAction(String action) {
    final value = action.toLowerCase();
    if (value.contains('order')) return Icons.receipt_long;
    if (value.contains('dispatch')) return Icons.local_shipping;
    if (value.contains('stock_entry') || value.contains('stock')) {
      return Icons.inventory_2;
    }
    if (value.contains('adjust')) return Icons.tune;
    if (value.contains('rejection')) return Icons.cancel_outlined;
    return Icons.bolt;
  }

  String _descriptionFor(AuditLogEntry log) {
    final action = log.action.toLowerCase();
    final id = log.entityId;
    if (action == 'order_created') {
      return id == null ? 'Order created' : 'Order #$id created';
    }
    if (action == 'dispatch_created') {
      return id == null ? 'Dispatch completed' : 'Dispatch #$id completed';
    }
    if (action == 'stock_entry_created') {
      return id == null ? 'Stock received' : 'Stock entry #$id received';
    }
    if (action == 'stock_adjustment_created') {
      return id == null ? 'Inventory adjusted' : 'Adjustment #$id created';
    }
    if (action == 'rejection_created') {
      return id == null ? 'Rejection recorded' : 'Rejection #$id recorded';
    }
    if (id != null) {
      return '${log.entityType} #$id ${log.action}';
    }
    return '${log.entityType} ${log.action}';
  }
}
