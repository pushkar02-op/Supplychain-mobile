import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/stock_service.dart';

class StockEntryScreen extends StatefulWidget {
  const StockEntryScreen({super.key});

  @override
  State<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends State<StockEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  DateTime? _receivedDate;
  int? _selectedBatchId;
  String _source = '';
  String _pricePerUnit = '';
  String _totalCost = '';

  bool _isLoading = false;
  String _error = '';

  List<dynamic> _batches = [];

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final batches = await StockService.fetchBatches();
      if (mounted) {
        setState(() => _batches = batches);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null && mounted) {
      setState(() => _receivedDate = picked);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() ||
        _receivedDate == null ||
        _selectedBatchId == null) {
      setState(() {
        _error =
            _receivedDate == null
                ? 'Please pick a received date'
                : _selectedBatchId == null
                ? 'Please select a batch'
                : '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    print(
      "Form data: ${_receivedDate?.toIso8601String()}, $_source, $_pricePerUnit, $_totalCost, $_selectedBatchId",
    );

    final result = await StockService.addStockEntry(
      receivedDate: _receivedDate!.toIso8601String().split('T').first,
      source: _source,
      pricePerUnit: double.parse(_pricePerUnit),
      totalCost: double.parse(_totalCost),
      batchId: _selectedBatchId!,
      itemId: 1, // Ensure you pass itemId here
    );

    if (!mounted) return;

    print("API result: $result");

    if (result == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock entry added')));
      context.pop(); // go back
    } else {
      setState(() => _error = result.toString());
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Stock Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _batches.isEmpty
                ? _error.isNotEmpty
                    ? Center(
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                    : const Center(child: CircularProgressIndicator())
                : Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // Received Date
                      ListTile(
                        title: Text(
                          _receivedDate == null
                              ? 'Pick Received Date'
                              : 'Date: ${_receivedDate!.toLocal().toIso8601String().split('T')[0]}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 12),

                      // Batch Dropdown
                      DropdownButtonFormField<int>(
                        value: _selectedBatchId,
                        decoration: const InputDecoration(
                          labelText: 'Select Batch',
                        ),
                        items:
                            _batches.map((b) {
                              final id = b['id'] as int;
                              final label = 'Batch $id';
                              return DropdownMenuItem(
                                value: id,
                                child: Text(label),
                              );
                            }).toList(),
                        onChanged: (v) => setState(() => _selectedBatchId = v),
                        validator:
                            (v) => v == null ? 'Please select a batch' : null,
                      ),
                      const SizedBox(height: 12),

                      // Source
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Supplier/Source',
                        ),
                        onChanged: (v) => _source = v.trim(),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Enter supplier name'
                                    : null,
                      ),
                      const SizedBox(height: 12),

                      // Price per unit
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Price per Unit',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _pricePerUnit = v.trim(),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Enter price per unit'
                                    : null,
                      ),
                      const SizedBox(height: 12),

                      // Total cost
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Total Cost',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _totalCost = v.trim(),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Enter total cost'
                                    : null,
                      ),
                      const SizedBox(height: 20),

                      if (_error.isNotEmpty)
                        Text(_error, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child:
                            _isLoading
                                ? const CircularProgressIndicator()
                                : const Text('Submit'),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
