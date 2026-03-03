import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/audit_log_entry.dart';
import '../providers/audit_provider.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_error_state.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(auditLogProvider);

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Audit Logs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, _) => AgroErrorState.loadFailed(
              message: err.toString(),
              onRetry: () => ref.read(auditLogProvider.notifier).refresh(),
            ),
        data:
            (state) => RefreshIndicator(
              onRefresh: () => ref.read(auditLogProvider.notifier).refresh(),
              child:
                  state.logs.isEmpty
                      ? const Center(child: Text('No audit logs found'))
                      : ListView.builder(
                        padding: const EdgeInsets.all(
                          AgroSpacing.screenPadding,
                        ),
                        itemCount: state.logs.length,
                        itemBuilder: (context, index) {
                          return _AuditLogCard(log: state.logs[index]);
                        },
                      ),
            ),
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  final AuditLogEntry log;

  const _AuditLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat(
      'MMM d, yyyy – HH:mm',
    ).format(log.createdAt.toLocal());

    final actionColor = switch (log.actionType.toUpperCase()) {
      'CREATE' || 'INSERT' => Colors.green,
      'DELETE' || 'DEACTIVATE' => Colors.red,
      'UPDATE' || 'ROLE_CHANGE' => Colors.orange,
      _ => Colors.blueGrey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AgroSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AgroShapes.cardRadius,
        side: const BorderSide(color: AgroColors.dividerLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.actionType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: actionColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.entityType,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formattedDate,
                  style: AgroTypography.cardSubtitle.copyWith(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'User #${log.actorUserId}',
                  style: AgroTypography.cardSubtitle,
                ),
                if (log.entityId != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.tag, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Entity #${log.entityId}',
                    style: AgroTypography.cardSubtitle,
                  ),
                ],
              ],
            ),
            if (log.eventMetadata != null && log.eventMetadata!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  log.eventMetadata!.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
