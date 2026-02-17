// stock_entry_screen.dart
import 'dart:async';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/stock_service.dart';
import '../ui/widgets/agro_snack_bar.dart';
import '../widgets/form/custom_date_picker.dart';

/// Screen mode for StockEntryScreen
enum StockEntryMode {
  receive, // Create new stock receipt
  correct, // Adjust existing stock (correction)
}

class StockEntryScreen extends StatefulWidget {
  const StockEntryScreen({super.key});

  @override
  State<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends State<StockEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Mode detection
  StockEntryMode _mode = StockEntryMode.receive;
  Map<String, dynamic>? _originalStock;

  // Receive mode fields
  DateTime _receivedDate = DateTime.now();
  Map<String, dynamic>? _selectedItem;
  String _quantity = '';
  String _unit = '';
  String _pricePerUnit = '';
  String _source = '';

  // Correct mode fields
  String _adjustmentQty = '';
  String _adjustmentReason = '';
  String? _selectedReason;

  // State
  bool _isLoading = false;
  String _error = '';
  bool _is409Error = false;
  List<dynamic> _items = [];
  List<String> _unitOptions = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = GoRouterState.of(context).extra;

    if (args != null && args is Map<String, dynamic>) {
      // Check for new format: {mode: 'correct', stock: {...}}
      if (args['mode'] == 'correct' && args['stock'] != null) {
        _mode = StockEntryMode.correct;
        _originalStock = args['stock'];
      } else {
        // Legacy format: direct stock object (treat as correction for safety)
        _mode = StockEntryMode.correct;
        _originalStock = args;
      }
    } else {
      _mode = StockEntryMode.receive;
    }
  }

  Future<void> _loadItems() async {
    try {
      final items = await StockService.fetchItems();
      items.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );
      if (mounted) {
        setState(() {
          _items = items;
          _unitOptions =
              items
                  .map((e) => e['default_unit'] as String?)
                  .where((u) => u != null)
                  .cast<String>()
                  .toSet()
                  .toList()
                ..sort();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _receivedDate = picked);
  }

  void _submitReceive() async {
    if (!_formKey.currentState!.validate() ||
        _receivedDate == null ||
        _selectedItem == null) {
      setState(() {
        _error =
            _receivedDate == null
                ? 'Please pick a date'
                : _selectedItem == null
                ? 'Please select an item'
                : '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });
    _formKey.currentState?.save();

    final qty = double.parse(_quantity);
    final price = double.parse(_pricePerUnit);

    final result = await StockService.addStockEntry(
      itemId: _selectedItem!['id'],
      receivedDate: _receivedDate.toIso8601String().split('T')[0],
      quantity: qty,
      unit: _unit,
      pricePerUnit: price,
      source: _source.isEmpty ? null : _source,
      totalCost: qty * price,
    );

    if (!mounted) return;

    if (result == true) {
      AgroSnackBar.success(context, 'Stock receipt saved');
      context.pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _error = result.toString();
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _submitCorrection() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedReason == null) {
      setState(() => _error = 'Please select a reason for this correction');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });
    _formKey.currentState?.save();

    // Parse adjustment qty (can be + or -)
    final adjustQty = double.tryParse(_adjustmentQty) ?? 0;
    if (adjustQty == 0) {
      setState(() {
        _isLoading = false;
        _error = 'Adjustment quantity cannot be zero';
      });
      return;
    }

    final batchId = _originalStock?['batch_id'];
    final unit = _originalStock?['unit'] ?? 'kg';

    if (batchId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Cannot determine batch for adjustment';
      });
      return;
    }

    // Compose reason from dropdown + optional notes
    final reasonLabels = {
      'counting_error': 'Counting error',
      'damaged_stock': 'Damaged stock',
      'found_extra': 'Found extra stock',
      'supplier_correction': 'Supplier correction',
      'other': 'Other',
    };
    String finalReason = reasonLabels[_selectedReason] ?? _selectedReason ?? '';
    if (_selectedReason == 'other' && _adjustmentReason.trim().isNotEmpty) {
      finalReason = 'Other: ${_adjustmentReason.trim()}';
    }

    final result = await StockService.createStockAdjustment(
      batchId: batchId,
      quantityDelta: adjustQty,
      unit: unit,
      reason: finalReason,
    );

    if (!mounted) return;

    if (result == true) {
      AgroSnackBar.success(context, 'Stock corrected');
      context.pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _error = result.toString();
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Widget _requiredLabel(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.black),
        children: const [
          TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCorrectMode = _mode == StockEntryMode.correct;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(isCorrectMode ? 'Correct Stock' : 'Receive Stock'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _buildBody(isCorrectMode),
    );
  }

  Widget _buildBody(bool isCorrectMode) {
    // Handle 409 error state
    if (_is409Error) {
      return _build409ErrorState();
    }

    // Handle general error on item load
    if (_error.isNotEmpty && _items.isEmpty) {
      return _buildLoadErrorState();
    }

    // Handle no items
    if (_items.isEmpty && !isCorrectMode) {
      return const Center(
        child: Text(
          'No items found. Please add items first.',
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
      );
    }

    if (isCorrectMode) {
      return _buildCorrectionForm();
    } else {
      return _buildReceiveForm();
    }
  }

  Widget _build409ErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 64, color: Colors.orange[400]),
          const SizedBox(height: 16),
          const Text(
            'This receipt cannot be edited',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Stock receipts are immutable. Use "Correct / Adjust" to record a correction.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Stock List'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(
            'Could not load items',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadItems,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectionForm() {
    final stock = _originalStock;
    if (stock == null) {
      return const Center(child: Text('No stock data available'));
    }

    final itemName = stock['item']?['name'] ?? 'Unknown Item';
    final receivedQty = (stock['quantity'] as num?)?.toDouble() ?? 0;
    final currentQty =
        (stock['batch_quantity'] as num?)?.toDouble() ?? receivedQty;
    final unit = stock['unit'] ?? '';
    final receivedDate = stock['received_date'] ?? '';

    // Calculate preview
    final adjustQty = double.tryParse(_adjustmentQty) ?? 0;
    final finalQty = currentQty + adjustQty;
    final adjustSign = adjustQty >= 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Top Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Correct stock',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Record a correction without rewriting history.\nAll corrections are recorded for audit.',
                    style: TextStyle(color: Colors.blue[700], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Original Receipt Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original receipt',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    const Divider(),
                    _buildSummaryRow('Item', itemName),
                    _buildSummaryRow('Receipt date', receivedDate),
                    _buildSummaryRow(
                      'Received qty',
                      '${receivedQty.toStringAsFixed(1)} $unit',
                    ),
                    _buildSummaryRow(
                      'Current qty',
                      '${currentQty.toStringAsFixed(1)} $unit',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Correction Inputs
            Text(
              'Correction details',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              decoration: InputDecoration(
                label: _requiredLabel('Adjustment quantity'),
                helperText: 'Use + to add, − to reduce (e.g., +5 or -2)',
                suffixText: unit,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              onChanged: (v) => setState(() => _adjustmentQty = v.trim()),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter adjustment quantity';
                final parsed = double.tryParse(v);
                if (parsed == null) return 'Enter a valid number';
                if (parsed == 0) return 'Adjustment cannot be zero';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Reason Dropdown
            DropdownButtonFormField<String>(
              decoration: InputDecoration(label: _requiredLabel('Reason')),
              value: _selectedReason,
              items: const [
                DropdownMenuItem(
                  value: 'counting_error',
                  child: Text('Counting error'),
                ),
                DropdownMenuItem(
                  value: 'damaged_stock',
                  child: Text('Damaged stock'),
                ),
                DropdownMenuItem(
                  value: 'found_extra',
                  child: Text('Found extra stock'),
                ),
                DropdownMenuItem(
                  value: 'supplier_correction',
                  child: Text('Supplier correction'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _selectedReason = v),
              validator: (v) => v == null ? 'Select a reason' : null,
            ),

            // Notes field (shown for "Other" reason)
            if (_selectedReason == 'other') ...[
              const SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  label: _requiredLabel('Details'),
                  helperText: 'Explain why this correction is needed',
                ),
                maxLines: 2,
                onChanged: (v) => _adjustmentReason = v,
                validator:
                    (v) =>
                        _selectedReason == 'other' &&
                                (v == null || v.trim().isEmpty)
                            ? 'Details required for "Other"'
                            : null,
              ),
            ],
            const SizedBox(height: 20),

            // Preview Section
            if (_adjustmentQty.isNotEmpty && adjustQty != 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: adjustQty > 0 ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        adjustQty > 0
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.preview,
                          size: 18,
                          color:
                              adjustQty > 0
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Preview',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color:
                                adjustQty > 0
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey[800], fontSize: 13),
                        children: [
                          const TextSpan(
                            text: 'This will adjust inventory by ',
                          ),
                          TextSpan(
                            text:
                                '$adjustSign${adjustQty.toStringAsFixed(1)} $unit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  adjustQty > 0
                                      ? Colors.green[700]
                                      : Colors.orange[700],
                            ),
                          ),
                          const TextSpan(text: '.\n'),
                          const TextSpan(text: 'Final stock will become '),
                          TextSpan(
                            text: '${finalQty.toStringAsFixed(1)} $unit',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitCorrection,
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Record correction'),
            ),
            const SizedBox(height: 8),
            Text(
              'This does not change the original receipt.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            CustomDatePicker(
              selectedDate: _receivedDate,
              onTap: _pickDate,
              enabled: true,
              label: _requiredLabel('Date'),
            ),
            const SizedBox(height: 12),
            DropdownSearch<Map<String, dynamic>>(
              asyncItems: (String filter) async {
                await Future.delayed(const Duration(milliseconds: 500));
                if (filter.isEmpty) {
                  return _items.cast<Map<String, dynamic>>();
                }
                final lower = filter.toLowerCase();
                return _items
                    .cast<Map<String, dynamic>>()
                    .where(
                      (item) => (item['name'] as String).toLowerCase().contains(
                        lower,
                      ),
                    )
                    .toList();
              },
              selectedItem: _selectedItem,
              itemAsString: (item) => item['name'] as String,
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  label: _requiredLabel('Select Item'),
                ),
              ),
              popupProps: PopupProps.dialog(
                showSearchBox: true,
                searchFieldProps: const TextFieldProps(
                  decoration: InputDecoration(hintText: 'Search item...'),
                ),
              ),
              onChanged: (item) {
                if (item != null) {
                  setState(() {
                    _selectedItem = item;
                    _unit = item['default_unit'] as String;
                  });
                }
              },
              validator:
                  (item) => item == null ? 'Please select an item' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _quantity,
              decoration: InputDecoration(
                label: _requiredLabel('Quantity'),
                helperText: 'Enter the quantity received',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _quantity = v.trim(),
              onSaved: (v) => _quantity = v?.trim() ?? '',
              validator:
                  (v) => v == null || v.isEmpty ? 'Enter quantity' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _unit.isNotEmpty ? _unit : null,
              decoration: InputDecoration(label: _requiredLabel('Unit')),
              items:
                  {..._unitOptions, if (_unit.isNotEmpty) _unit}
                      .where((u) => u.isNotEmpty)
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
              onChanged: (v) => setState(() => _unit = v ?? ''),
              onSaved: (v) => _unit = v ?? '',
              validator: (v) => v == null || v.isEmpty ? 'Enter unit' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _pricePerUnit,
              decoration: InputDecoration(
                label: _requiredLabel('Price per Unit'),
                helperText: 'Price in ₹ per unit',
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => _pricePerUnit = v.trim(),
              onSaved: (v) => _pricePerUnit = v?.trim() ?? '',
              validator: (v) => v == null || v.isEmpty ? 'Enter price' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _source,
              decoration: const InputDecoration(labelText: 'Source (optional)'),
              onChanged: (v) => _source = v.trim(),
            ),
            const SizedBox(height: 8),

            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitReceive,
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Save Receipt'),
            ),
          ],
        ),
      ),
    );
  }
}
