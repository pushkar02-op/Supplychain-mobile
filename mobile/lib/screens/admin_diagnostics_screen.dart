import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_diagnostics_provider.dart';
import '../ui/semantics/agro_severity.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_section.dart';

class AdminDiagnosticsScreen extends ConsumerWidget {
  const AdminDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missingItemsAsync = ref.watch(missingDefaultUOMProvider);

    return Scaffold(
      backgroundColor: AgroColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('System Diagnostics'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          return ref.refresh(missingDefaultUOMProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AgroSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: AgroSpacing.xl),
              _buildUOMSection(context, ref, missingItemsAsync),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final severity = AgroSeverity.fromStatus(AgroStatus.info);

    return Container(
      padding: const EdgeInsets.all(AgroSpacing.lg),
      decoration: BoxDecoration(
        color: severity.backgroundColor,
        borderRadius: AgroShapes.cardRadius,
        border: Border.all(color: severity.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.monitor_heart_outlined,
            color: severity.iconColor,
            size: 28,
          ),
          const SizedBox(width: AgroSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory Health Monitor',
                  style: AgroTypography.cardTitle.copyWith(
                    color: severity.textColor,
                  ),
                ),
                const SizedBox(height: AgroSpacing.xs),
                Text(
                  'Read-only diagnostic data. Contact support to resolve configuration issues.',
                  style: AgroTypography.caption.copyWith(
                    color: severity.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUOMSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> asyncValue,
  ) {
    return AgroSection(
      title: 'UOM Configuration Risks',
      subtitle: 'Items with missing default units. Operations are blocked.',
      child: asyncValue.when(
        data: (items) {
          if (items.isEmpty) {
            return AgroEmptyState(
              icon: Icons.check_circle_outline,
              iconColor: AgroColors.success.text,
              title: 'All items configured correctly',
              message: 'No missing default UOMs detected.',
              iconSize: 48,
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AgroSpacing.md),
            itemBuilder: (context, index) {
              return _DiagnosticItemCard(item: items[index]);
            },
          );
        },
        loading:
            () => const Padding(
              padding: EdgeInsets.all(AgroSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
        error:
            (err, stack) => AgroErrorState(
              title: 'Error loading diagnostics',
              message: err.toString(),
            ),
      ),
    );
  }
}

/// Diagnostic item card showing a configuration warning.
class _DiagnosticItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _DiagnosticItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final warningSeverity = AgroSeverity.fromStatus(AgroStatus.major);
    final criticalSeverity = AgroSeverity.fromStatus(AgroStatus.critical);

    return AgroCard.outlined(
      borderColor: warningSeverity.borderColor,
      padding: const EdgeInsets.all(AgroSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning icon container
          Container(
            padding: const EdgeInsets.all(AgroSpacing.sm + 2), // 10px
            decoration: BoxDecoration(
              color: warningSeverity.backgroundColor,
              borderRadius: AgroShapes.containerRadius,
            ),
            child: Icon(
              warningSeverity.icon,
              color: warningSeverity.iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AgroSpacing.lg),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Unknown Item',
                  style: AgroTypography.cardTitle,
                ),
                const SizedBox(height: AgroSpacing.xs),
                Text(
                  'ID: ${item['id']} • Code: ${item['item_code'] ?? 'N/A'}',
                  style: AgroTypography.caption.copyWith(
                    fontFamily: 'Monospace',
                  ),
                ),
                const SizedBox(height: AgroSpacing.sm),
                // Blocked badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AgroSpacing.sm,
                    vertical: AgroSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: criticalSeverity.backgroundColor,
                    borderRadius: AgroShapes.badgeRadius,
                  ),
                  child: Text(
                    'BLOCKED: Missing Default UOM',
                    style: AgroTypography.badgeText.copyWith(
                      color: criticalSeverity.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
