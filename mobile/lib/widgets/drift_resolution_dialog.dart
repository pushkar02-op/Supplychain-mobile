import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/snackbar_service.dart';
import '../models/drift_item.dart';
import '../providers/admin_ledger_provider.dart';

class DriftResolutionDialog extends ConsumerStatefulWidget {
  final DriftItem item;

  const DriftResolutionDialog({super.key, required this.item});

  static Future<bool> show(BuildContext context, DriftItem item) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DriftResolutionDialog(item: item),
    );
    return result ?? false;
  }

  @override
  ConsumerState<DriftResolutionDialog> createState() =>
      _DriftResolutionDialogState();
}

class _DriftResolutionDialogState
    extends ConsumerState<DriftResolutionDialog> {
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  String _resolutionType = 'state_to_ledger';

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasDrift = item.drift != 0;
    final unsupportedSelected = _resolutionType == 'ledger_to_state';

    return AlertDialog(
      title: const Text('Resolve Drift'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batch ID: ${item.batchId}'),
            Text('Item ID: ${item.itemId}'),
            Text('State Qty: ${item.stateQty.toStringAsFixed(3)}'),
            Text('Ledger Qty: ${item.ledgerQty.toStringAsFixed(3)}'),
            Text('Drift: ${item.drift.toStringAsFixed(3)}'),
            const SizedBox(height: 16),
            RadioListTile<String>(
              value: 'state_to_ledger',
              groupValue: _resolutionType,
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _resolutionType = value!),
              title: const Text('Adjust LEDGER to match STATE'),
              subtitle: const Text('Supported resolution path'),
            ),
            RadioListTile<String>(
              value: 'ledger_to_state',
              groupValue: _resolutionType,
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _resolutionType = value!),
              title: const Text('Adjust STATE to match LEDGER'),
              subtitle: const Text(
                'Unavailable with current reconciliation semantics',
              ),
            ),
            TextField(
              controller: _notesController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
              minLines: 2,
              maxLines: 4,
            ),
            if (unsupportedSelected) ...[
              const SizedBox(height: 8),
              const Text(
                'Only adjusting the ledger to match the current state is currently supported by the backend contract.',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (!hasDrift || _isSubmitting || unsupportedSelected)
              ? null
              : _resolve,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Resolve'),
        ),
      ],
    );
  }

  Future<void> _resolve() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(driftReportProvider.notifier).resolveDriftBatch(
            widget.item,
            _resolutionType,
            notes: _notesController.text,
          );
      if (!mounted) return;
      SnackbarService.showSuccess(context, 'Inventory drift resolved');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      SnackbarService.showError(context, 'Failed to resolve drift: $e');
      setState(() => _isSubmitting = false);
    }
  }
}
