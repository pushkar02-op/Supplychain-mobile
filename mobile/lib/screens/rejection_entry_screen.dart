import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/rejection_service.dart';

class RejectionEntryScreen extends StatefulWidget {
  const RejectionEntryScreen({Key? key}) : super(key: key);

  @override
  State<RejectionEntryScreen> createState() => _RejectionEntryScreenState();
}

class _RejectionEntryScreenState extends State<RejectionEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // form fields
  Map<String, dynamic>? _selectedItem;
  int? _selectedBatchId;
  String _unit = '';
  double _available = 0;
  double _quantity = 0;
  String _reason = '';
  DateTime _rejectionDate = DateTime.now();

  // lists
  List<Map<String, dynamic>> _items = []; // assume you load items elsewhere
  List<dynamic> _batches = [];

  bool _loadingBatches = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await RejectionService.fetchItemsWithBatches();
      setState(() => _items = items);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _loadBatches(int itemId) async {
    setState(() {
      _loadingBatches = true;
      _batches = [];
      _selectedBatchId = null;
      _available = 0;
      _unit = '';
    });
    try {
      final all = await RejectionService.fetchBatches(itemId: itemId);
      // sort FCFS by received_at
      all.sort((a, b) {
        return DateTime.parse(
          a['received_at'],
        ).compareTo(DateTime.parse(b['received_at']));
      });
      setState(() => _batches = all);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingBatches = false);
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _rejectionDate,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null) setState(() => _rejectionDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _selectedItem == null ||
        _selectedBatchId == null)
      return;
    _formKey.currentState!.save();

    setState(() => _submitting = true);
    try {
      await RejectionService.createRejection(
        itemId: _selectedItem!['id'] as int,
        batchId: _selectedBatchId!,
        quantity: _quantity,
        unit: _unit,
        reason: _reason,
        rejectionDate: DateFormat('yyyy-MM-dd').format(_rejectionDate),
        rejectedBy: 'currentUser',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rejection saved')));
      context.pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejection Entry')),
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
                      // Item selector
                      DropdownSearch<Map<String, dynamic>>(
                        items: _items,
                        itemAsString: (i) => i['name'] as String,
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: const InputDecoration(
                            labelText: 'Item *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        onChanged: (item) {
                          if (item != null &&
                              item['id'] != _selectedItem?['id']) {
                            setState(() {
                              _selectedItem = item;
                              _selectedBatchId = null;
                              _available = 0;
                              _unit = '';
                            });
                            _loadBatches(item['id'] as int);
                          }
                        },
                        validator:
                            (i) => i == null ? 'Please select an item' : null,
                      ),
                      const SizedBox(height: 12),

                      // Batch selector
                      _loadingBatches
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<int>(
                            value: _selectedBatchId,
                            decoration: const InputDecoration(
                              labelText: 'Batch *',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                _batches.map((b) {
                                  final qty = (b['quantity'] as num).toDouble();
                                  return DropdownMenuItem<int>(
                                    value: b['id'] as int,
                                    child: Text(
                                      '${b['received_at']} (Exp: ${b['expiry_date']}) — $qty ${b['unit']}',
                                    ),
                                  );
                                }).toList(),
                            onChanged: (v) {
                              final batch = _batches.firstWhere(
                                (b) => b['id'] == v,
                              );
                              setState(() {
                                _selectedBatchId = v;
                                _available =
                                    (batch['quantity'] as num).toDouble();
                                _unit = batch['unit'] as String;
                              });
                            },
                            validator:
                                (v) =>
                                    v == null ? 'Please select a batch' : null,
                          ),
                      const SizedBox(height: 12),

                      // Available
                      Text('Available: $_available $_unit'),
                      const SizedBox(height: 12),

                      // Quantity to reject
                      TextFormField(
                        initialValue: '0',
                        decoration: InputDecoration(
                          labelText: 'Quantity to Reject * ($_unit)',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final val = double.tryParse(v ?? '');
                          if (val == null || val <= 0)
                            return 'Enter a valid qty';
                          if (val > _available)
                            return 'Cannot exceed available';
                          return null;
                        },
                        onSaved: (v) => _quantity = double.parse(v!),
                      ),
                      const SizedBox(height: 12),

                      // Reason
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Reason *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Enter a reason'
                                    : null,
                        onSaved: (v) => _reason = v!.trim(),
                      ),
                      const SizedBox(height: 12),

                      // Date
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Date: ${DateFormat('yyyy-MM-dd').format(_rejectionDate)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 24),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child:
                              _submitting
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text('Submit'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
