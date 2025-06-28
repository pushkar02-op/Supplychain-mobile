// lib/screens/dispatch_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/dispatch_service.dart';

class CreateOrEditDispatchScreen extends StatefulWidget {
  final Map<String, dynamic>? data;
  const CreateOrEditDispatchScreen({super.key, this.data});

  @override
  State<CreateOrEditDispatchScreen> createState() =>
      _CreateOrEditDispatchScreenState();
}

class _BatchRow {
  final int batchId;
  final String receivedAt;
  final String unit;
  final double available;
  bool selected;
  double qty;

  _BatchRow({
    required this.batchId,
    required this.receivedAt,
    required this.unit,
    required this.available,
  }) : selected = false,
       qty = 0;
}

class _CreateOrEditDispatchScreenState
    extends State<CreateOrEditDispatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarksCtl = TextEditingController();

  late int _itemId;
  late String _martName;
  late String _unit;
  late String _dispatchDate;
  late double _alreadyDispatched;
  late double _orderQuantity;

  List<_BatchRow> _rows = [];
  bool _loading = true, _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.data!;
    _itemId = d['item_id'] as int;
    _alreadyDispatched = (d['quantity_dispatched'] as num? ?? 0).toDouble();
    _orderQuantity = (d['quantity_ordered'] as num? ?? 0).toDouble();
    _martName = d['mart_name'] as String? ?? '';
    _unit = d['unit'] as String? ?? '';
    _dispatchDate =
        d['dispatch_date'] as String? ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    _remarksCtl.text = d['remarks'] ?? '';
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final all = await DispatchService.fetchBatches(itemId: _itemId);
      final remaining = (_orderQuantity - _alreadyDispatched).clamp(
        0.0,
        double.infinity,
      );
      all.sort(
        (a, b) => DateTime.parse(
          a['received_at'],
        ).compareTo(DateTime.parse(b['received_at'])),
      );

      final filtered =
          all
              .map(
                (b) => _BatchRow(
                  batchId: b['id'] as int,
                  receivedAt: b['received_at'] as String,
                  unit: b['unit'] as String,
                  available: (b['quantity'] as num).toDouble(),
                ),
              )
              .toList();

      // auto-select FCFS to cover remaining
      double toCover = remaining;
      for (var row in filtered) {
        if (toCover <= 0) break;
        row.selected = true;
        row.qty = row.available.clamp(0, toCover);
        toCover -= row.qty;
      }

      setState(() {
        _rows = filtered;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load batches: $e';
        _loading = false;
      });
    }
  }

  double get _totalNow =>
      _rows.where((r) => r.selected).fold(0.0, (sum, r) => sum + r.qty);

  double get _remaining =>
      (_orderQuantity - _alreadyDispatched).clamp(0.0, double.infinity);

  double _totalNowExcluding(_BatchRow exclude) => _rows
      .where((r) => r.selected && r != exclude)
      .fold(0.0, (sum, r) => sum + r.qty);

  bool get _canSave => _totalNow > 0 && !_submitting;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_canSave) return;

    // Over-dispatch confirmation
    if (_totalNow > _remaining) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Over-dispatch Warning'),
              content: Text(
                'You are dispatching more (${_totalNow.toStringAsFixed(2)} $_unit) than remaining (${_remaining.toStringAsFixed(2)} $_unit).\nProceed?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Proceed'),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
    }

    setState(() => _submitting = true);

    final payload = {
      'item_id': _itemId,
      'mart_name': _martName,
      'dispatch_date': _dispatchDate,
      'unit': _unit,
      'remarks': _remarksCtl.text.trim(),
      'batches':
          _rows
              .where((r) => r.selected)
              .map(
                (r) => {
                  'batch_id': r.batchId,
                  'quantity': double.parse(r.qty.toStringAsFixed(2)),
                },
              )
              .toList(),
    };
    try {
      if (widget.data!['id'] != null) {
        await DispatchService.updateDispatch(
          widget.data!['id'] as int,
          payload,
        );
      } else {
        await DispatchService.createDispatch(payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispatch saved successfully')),
      );
      context.pop(true);
    } catch (e) {
      setState(() {
        _error = _parseError(e);
      });
    } finally {
      setState(() => _submitting = false);
    }
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('Not enough stock')) {
      return 'Not enough stock in selected batch. Please refresh and try again.';
    }
    if (msg.contains('unique constraint')) {
      return 'Duplicate dispatch entry for this item, date, and mart.';
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child:
              _error != null
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBatches,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                  : const CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.data!['id'] != null ? 'Edit Dispatch' : 'New Dispatch',
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // read-only item
              TextFormField(
                initialValue: widget.data!['item_name'] as String? ?? '',
                decoration: InputDecoration(
                  labelText: 'Item',
                  border: const OutlineInputBorder(),
                  suffixIcon: Tooltip(
                    message: 'The item being dispatched.',
                    child: const Icon(Icons.info_outline),
                  ),
                ),
                enabled: false,
              ),
              const SizedBox(height: 12),
              // read-only mart
              TextFormField(
                initialValue: _martName,
                decoration: InputDecoration(
                  labelText: 'Mart',
                  border: const OutlineInputBorder(),
                  suffixIcon: Tooltip(
                    message: 'The mart/store for this dispatch.',
                    child: const Icon(Icons.info_outline),
                  ),
                ),
                enabled: false,
              ),
              const SizedBox(height: 12),
              // read-only date
              TextFormField(
                initialValue: _dispatchDate,
                decoration: InputDecoration(
                  labelText: 'Date',
                  border: const OutlineInputBorder(),
                  suffixIcon: Tooltip(
                    message: 'The date of dispatch.',
                    child: const Icon(Icons.info_outline),
                  ),
                ),
                enabled: false,
              ),
              const SizedBox(height: 12),

              // summary
              Row(
                children: [
                  Text(
                    'Remaining to dispatch: ${_remaining.toStringAsFixed(2)} $_unit',
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message:
                        'Order quantity minus already dispatched. You should not dispatch more than this unless intentionally over-dispatching.',
                    child: const Icon(Icons.info_outline, size: 18),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Dispatching now: ${_totalNow.toStringAsFixed(2)} $_unit',
                    style: TextStyle(
                      color: _totalNow > _remaining ? Colors.red : null,
                    ),
                  ),
                  if (_totalNow > _remaining)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Tooltip(
                        message:
                            'You are dispatching more than the remaining order quantity.',
                        child: Icon(Icons.warning, color: Colors.red, size: 18),
                      ),
                    ),
                ],
              ),
              const Divider(height: 32),

              // batch rows: whole row tappable
              ..._rows.map((r) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      r.selected = !r.selected;
                      if (!r.selected) {
                        r.qty = 0;
                      } else {
                        final remaining = _remaining - _totalNowExcluding(r);
                        r.qty = remaining.clamp(0, r.available);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: r.selected ? Colors.blue : Colors.grey.shade300,
                          width: 6,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      title: Text(
                        '${r.receivedAt} — ${r.available.toStringAsFixed(2)} ${r.unit}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        'Available: ${r.available.toStringAsFixed(2)} ${r.unit}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      trailing: SizedBox(
                        width: 80,
                        child: TextFormField(
                          enabled: r.selected,
                          initialValue: r.qty.toStringAsFixed(2),
                          decoration: const InputDecoration(
                            labelText: 'Qty',
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (txt) {
                            final v = double.tryParse(txt) ?? 0;
                            setState(() {
                              r.qty = v.clamp(0, r.available);
                            });
                          },
                          validator: (txt) {
                            if (!r.selected) return null;
                            final v = double.tryParse(txt ?? '') ?? 0;
                            if (v <= 0 || v > r.available) {
                              return '0–${r.available}';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),
              // remarks
              TextFormField(
                controller: _remarksCtl,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                maxLines: 2,
                maxLength: 200,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_remarksCtl.text.length}/200',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),

              // save
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSave ? _save : null,
                  child:
                      _submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Dispatch'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
