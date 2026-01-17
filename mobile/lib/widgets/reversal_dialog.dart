import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReversalDialog extends StatefulWidget {
  final int dispatchId;
  final double? maxQuantity;
  final String itemName;
  final String martName;
  final String dispatchDate;

  const ReversalDialog({
    super.key,
    required this.dispatchId,
    required this.itemName,
    required this.martName,
    required this.dispatchDate,
    this.maxQuantity,
  });

  @override
  State<ReversalDialog> createState() => _ReversalDialogState();
}

class _ReversalDialogState extends State<ReversalDialog> {
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _isFullReversal = true;
  double _reversalQty = 0;

  @override
  void initState() {
    super.initState();
    _reversalQty = widget.maxQuantity ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    // Format text
    final dateStr = DateFormat(
      'EEE, MMM d',
    ).format(DateTime.parse(widget.dispatchDate));
    final qtyDisplay =
        _isFullReversal
            ? '${widget.maxQuantity?.toStringAsFixed(0) ?? '?'} kg'
            : '${_reversalQty.toStringAsFixed(0)} kg';

    return AlertDialog(
      title: const Text('Confirm Reversal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. What is being reversed
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                      children: [
                        const TextSpan(text: 'Reversing '),
                        TextSpan(
                          text:
                              '${widget.maxQuantity?.toStringAsFixed(0)} kg of ${widget.itemName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dispatched to ${widget.martName}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'On $dateStr',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // B. Impact Analysis
            const Text(
              'Consequences:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _buildImpactRow(
              icon: Icons.inventory_2,
              text: 'Returns $qtyDisplay to inventory',
            ),
            const SizedBox(height: 4),
            _buildImpactRow(
              icon: Icons.restore_page,
              text: 'Order status: Fully → Partially Dispatched',
              isBold: true,
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
                    _reversalQty = widget.maxQuantity ?? 0;
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
                  hintText: 'Max: ${widget.maxQuantity}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) {
                  setState(() {
                    _reversalQty = double.tryParse(val) ?? 0;
                  });
                },
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            double? finalQty;
            if (!_isFullReversal) {
              finalQty = double.tryParse(_qtyCtrl.text);
              if (finalQty == null ||
                  finalQty <= 0 ||
                  finalQty > (widget.maxQuantity ?? 0)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid quantity')),
                );
                return;
              }
            } else {
              finalQty = widget.maxQuantity;
            }

            Navigator.pop(context, {
              'quantity': finalQty,
              'reason': _reasonCtrl.text.trim(),
            });
          },
          child: const Text('Confirm Reversal'),
        ),
      ],
    );
  }

  Widget _buildImpactRow({
    required IconData icon,
    required String text,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.black87 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}
