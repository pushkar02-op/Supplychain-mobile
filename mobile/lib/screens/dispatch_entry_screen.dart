// lib/screens/dispatch_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/dispatch_provider.dart';
import '../ui/widgets/agro_snack_bar.dart';

class CreateOrEditDispatchScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? data;
  const CreateOrEditDispatchScreen({super.key, this.data});

  @override
  ConsumerState<CreateOrEditDispatchScreen> createState() =>
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
    extends ConsumerState<CreateOrEditDispatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarksCtl = TextEditingController();

  late int _itemId;
  late String _martName;
  late String _unit;
  late String _dispatchDate;
  late double _alreadyDispatched;
  late double _orderQuantity;
  int? _orderId;

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
    _orderId = d['order_id'] as int?;
    _remarksCtl.text = d['remarks'] ?? '';
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final all = await ref
          .read(dispatchListProvider.notifier)
          .fetchBatches(itemId: _itemId);
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

      if (mounted) {
        setState(() {
          _rows = filtered;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load batches: $e';
          _loading = false;
        });
      }
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are dispatching ${_totalNow.toStringAsFixed(2)} $_unit, but the order remaining is ${_remaining.toStringAsFixed(2)} $_unit.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This will exceed the planned order quantity.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Proceed Anyway'),
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
      'order_id': _orderId,
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
        throw Exception('Editing dispatch entries is not allowed.');
      }
      await ref.read(dispatchListProvider.notifier).createDispatch(payload);
      if (!mounted) return;
      AgroSnackBar.success(context, 'Dispatch saved successfully');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _parseError(e);
          _submitting = false;
        });
      }
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
        appBar: AppBar(title: const Text('Dispatching...')),
        body: Center(
          child:
              _error != null
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
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

    final dateStr = DateFormat(
      'EEEE, MMM d, yyyy',
    ).format(DateTime.parse(_dispatchDate));

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light bg for better contrast
      appBar: AppBar(
        title: const Text('New Dispatch'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Context Locking (Top Anchor)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 15, color: Colors.black),
                      children: [
                        const TextSpan(text: 'Dispatching '),
                        TextSpan(
                          text: widget.data!['item_name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' to '),
                        TextSpan(
                          text: _martName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For $dateStr',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 2. Remaining Quantity (Primary Signal)
            Container(
              width: double.infinity,
              color: Colors.blue[50],
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    'Remaining to Dispatch'.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_remaining.toStringAsFixed(2)} $_unit',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Body
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 3. Batch Selection
                    const Text(
                      'Select batches to dispatch from',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'No batches available for this item.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ..._rows.map((r) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  r.selected
                                      ? Colors.blue.shade200
                                      : Colors.grey.shade200,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                r.selected = !r.selected;
                                if (!r.selected) {
                                  r.qty = 0;
                                } else {
                                  final remaining =
                                      _remaining - _totalNowExcluding(r);
                                  r.qty = remaining.clamp(0, r.available);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: r.selected,
                                    onChanged: (v) {
                                      setState(() {
                                        r.selected = v == true;
                                        if (!r.selected) {
                                          r.qty = 0;
                                        } else {
                                          final remaining =
                                              _remaining -
                                              _totalNowExcluding(r);
                                          r.qty = remaining.clamp(
                                            0,
                                            r.available,
                                          );
                                        }
                                      });
                                    },
                                    activeColor: Colors.blue[800],
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Received ${r.receivedAt}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Available: ${r.available.toStringAsFixed(2)} ${r.unit}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: TextFormField(
                                      enabled: r.selected,
                                      initialValue: r.qty.toStringAsFixed(2),
                                      key: ValueKey(
                                        '${r.batchId}-${r.qty}',
                                      ), // rebuild on value change logic
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText: 'Qty',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 10,
                                            ),
                                        border: const OutlineInputBorder(),
                                        filled: true,
                                        fillColor:
                                            r.selected
                                                ? Colors.white
                                                : Colors.grey[100],
                                      ),
                                      textAlign: TextAlign.right,
                                      onChanged: (val) {
                                        final v = double.tryParse(val) ?? 0;
                                        setState(() {
                                          // clamp immediately for safety or validate on saved?
                                          // UX says "clamped" -> we clamp the internal state but maybe logic needed here
                                          // Let's just update state, clamp on submit or visual feedback
                                          r.qty = v.clamp(0, r.available);
                                        });
                                      },
                                      validator: (val) {
                                        if (!r.selected) return null;
                                        final v =
                                            double.tryParse(val ?? '') ?? 0;
                                        if (v <= 0 || v > r.available) {
                                          return 'Inv';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _remarksCtl,
                      decoration: const InputDecoration(
                        labelText: 'Remarks (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),

            // 4. Dispatching Now (Live Summary) + Action
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Dispatching Now',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              _totalNow > _remaining
                                  ? Colors.red[700]
                                  : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_totalNow.toStringAsFixed(2)} $_unit',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color:
                              _totalNow > _remaining
                                  ? Colors.red[700]
                                  : Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  if (_totalNow > _remaining)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Exceeds remaining quantity by ${(_totalNow - _remaining).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _totalNow > _remaining
                                ? Colors.orange[800]
                                : Colors.green[700],
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child:
                          _submitting
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : Text(
                                _totalNow > _remaining
                                    ? 'Confirm Over-dispatch'
                                    : 'Save Dispatch',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
