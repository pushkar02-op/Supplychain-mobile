import 'package:flutter/material.dart';

class ReversalDialog extends StatefulWidget {
  final int dispatchId;
  final double?
  maxQuantity; // If known, otherwise null (full reversal assumed default)

  const ReversalDialog({super.key, required this.dispatchId, this.maxQuantity});

  @override
  State<ReversalDialog> createState() => _ReversalDialogState();
}

class _ReversalDialogState extends State<ReversalDialog> {
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _isFullReversal = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reverse Dispatch'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reverse Dispatch #${widget.dispatchId}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action will restore stock and adjust the order status. It cannot be undone.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Full Reversal'),
              value: _isFullReversal,
              onChanged: (v) {
                setState(() {
                  _isFullReversal = v == true;
                  if (_isFullReversal) {
                    _qtyCtrl.clear();
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (!_isFullReversal)
              TextField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Quantity to Reverse',
                  hintText:
                      widget.maxQuantity != null
                          ? 'Max: ${widget.maxQuantity}'
                          : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (Optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: () {
            double? qty;
            if (!_isFullReversal) {
              qty = double.tryParse(_qtyCtrl.text);
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid quantity')),
                );
                return;
              }
            }

            Navigator.pop(context, {
              'quantity': qty,
              'reason': _reasonCtrl.text.trim(),
            });
          },
          child: const Text('Confirm Reversal'),
        ),
      ],
    );
  }
}
