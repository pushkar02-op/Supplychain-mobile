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

  // order context
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
          all.map((b) {
            return _BatchRow(
              batchId: b['id'] as int,
              receivedAt: b['received_at'] as String,
              unit: b['unit'] as String,
              available: (b['quantity'] as num).toDouble(),
            );
          }).toList();

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

  // only require >0, no upper-bound
  bool get _canSave => _totalNow > 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_canSave) return;
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
              .map((r) => {'batch_id': r.batchId, 'quantity': r.qty})
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispatch saved successfully')),
      );
      context.pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.data!['id'] != null ? 'Edit Dispatch' : 'New Dispatch',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _error != null
                ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
                : Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // read-only item
                      TextFormField(
                        initialValue:
                            widget.data!['item_name'] as String? ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Item',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 12),
                      // read-only mart
                      TextFormField(
                        initialValue: _martName,
                        decoration: const InputDecoration(
                          labelText: 'Mart',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 12),
                      // read-only date
                      TextFormField(
                        initialValue: _dispatchDate,
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 12),

                      // summary
                      Text(
                        'Remaining to dispatch: ${_remaining.toStringAsFixed(2)} $_unit',
                      ),
                      Text(
                        'Dispatching now: ${_totalNow.toStringAsFixed(2)} $_unit',
                        style: TextStyle(
                          color: _totalNow > _remaining ? Colors.red : null,
                        ),
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
                                // clamp to batch available (no upper bound on order)
                                r.qty = r.available;
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Checkbox(value: r.selected, onChanged: null),
                                Expanded(
                                  child: Text(
                                    '${r.receivedAt} — '
                                    '${r.available.toStringAsFixed(2)} ${r.unit}',
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    enabled: r.selected,
                                    initialValue: r.qty.toStringAsFixed(2),
                                    decoration: const InputDecoration(
                                      labelText: 'Qty',
                                      isDense: true,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
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
                              ],
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
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // save
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _canSave && !_submitting ? _save : null,
                          child:
                              _submitting
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
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
