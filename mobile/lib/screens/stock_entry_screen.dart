// stock_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/stock_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:async';

class StockEntryScreen extends StatefulWidget {
  const StockEntryScreen({super.key});

  @override
  State<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends State<StockEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime? _receivedDate = DateTime.now();
  Map<String, dynamic>? _selectedItem;
  String _quantity = '';
  String _unit = '';
  String _pricePerUnit = '';
  String _source = '';
  bool _isLoading = false;
  String _error = '';
  List<dynamic> _items = [];
  List<String> _unitOptions = [];

  Map<String, dynamic>? _editingStock;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Moved the navigation-related logic here, as it must happen after initState
    final args = GoRouterState.of(context).extra;
    if (args != null && args is Map<String, dynamic>) {
      _editingStock = args;
      _preFillStockData();
    }
  }

  void _preFillStockData() {
    if (_editingStock != null) {
      _receivedDate = DateTime.parse(_editingStock!['received_date']);
      _quantity = _editingStock!['quantity'].toString();
      _unit = _editingStock!['unit'] ?? '';
      _pricePerUnit = _editingStock!['price_per_unit'].toString();
      _source = _editingStock!['source'] ?? '';
      _selectedItem = _editingStock!['item'];
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
              items.map((e) => e['default_unit'] as String).toSet().toList()
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
      initialDate: _receivedDate ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _receivedDate = picked);
  }

  void _submit() async {
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
    final formState = _formKey.currentState;
    if (formState != null) {
      formState.save();
    }

    final qty = double.parse(_quantity);
    final price = double.parse(_pricePerUnit);

    final data = {
      'itemId': _selectedItem!['id'],
      'received_date': _receivedDate!.toIso8601String().split('T')[0],
      'quantity': qty,
      'unit': _unit,
      'price_per_unit': price,
      'source': _source.isEmpty ? null : _source,
      'total_cost': qty * price,
    };
    print(data);

    bool result = false;
    if (_editingStock != null) {
      result = await StockService.updateStockEntry(_editingStock!['id'], data);
    } else {
      result = await StockService.addStockEntry(
        itemId: data['itemId'],
        receivedDate: data['receivedDate'],
        quantity: data['quantity'],
        unit: data['unit'],
        pricePerUnit: data['pricePerUnit'],
        source: data['source'],
        totalCost: data['totalCost'],
      );
    }

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingStock != null ? 'Stock entry updated' : 'Stock entry added',
          ),
        ),
      );
      context.pop(true);
    } else {
      setState(() => _error = result.toString());
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          _editingStock != null ? 'EDIT STOCK ENTRY' : 'ADD STOCK ENTRY',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _error.isNotEmpty
                ? Center(
                  child: Text(
                    _error,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
                : _items.isEmpty
                ? const Center(
                  child: Text(
                    'No items found. Please add items first.',
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                )
                : Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      ListTile(
                        title: Text(
                          'Date: ${_receivedDate!.toIso8601String().split('T')[0]}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      if (_editingStock != null)
                        TextFormField(
                          initialValue:
                              _selectedItem != null
                                  ? _selectedItem!['name'] as String
                                  : '',
                          decoration: InputDecoration(
                            label: _requiredLabel('Selected Item'),
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor:
                                Colors.grey[200], // Light grey background
                          ),
                          enabled: false, // Make it read-only
                          style: const TextStyle(
                            color: Colors.black87,
                          ), // Text color
                        )
                      else
                        DropdownSearch<Map<String, dynamic>>(
                          asyncItems: (String filter) async {
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );
                            if (filter.isEmpty) {
                              return _items.cast<Map<String, dynamic>>();
                            }
                            final lower = filter.toLowerCase();
                            return _items
                                .cast<Map<String, dynamic>>()
                                .where(
                                  (item) => (item['name'] as String)
                                      .toLowerCase()
                                      .contains(lower),
                                )
                                .toList();
                          },
                          selectedItem: _selectedItem,
                          itemAsString: (item) => item['name'] as String,
                          // enabled: _editingStock == null,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              label: _requiredLabel('Select Item'),
                            ),
                          ),
                          popupProps: PopupProps.dialog(
                            showSearchBox: true,
                            searchFieldProps: const TextFieldProps(
                              decoration: InputDecoration(
                                hintText: 'Search item...',
                              ),
                            ),
                          ),
                          onChanged: (item) {
                            if (item != null && _editingStock == null) {
                              setState(() {
                                _selectedItem = item;
                                _unit = item['default_unit'] as String;
                              });
                            }
                          },
                          validator:
                              (item) =>
                                  item == null ? 'Please select an item' : null,
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _quantity,
                        decoration: InputDecoration(
                          label: _requiredLabel('Quantity'),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _quantity = v.trim(),
                        onSaved: (v) => _quantity = v?.trim() ?? '',
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Enter quantity'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _unit.isNotEmpty ? _unit : null,
                        decoration: InputDecoration(
                          label: _requiredLabel('Unit'),
                        ),
                        items:
                            _unitOptions
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _unit = v ?? ''),
                        onSaved: (v) => _unit = v ?? '',
                        validator:
                            (v) => v == null || v.isEmpty ? 'Enter unit' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _pricePerUnit,
                        decoration: InputDecoration(
                          label: _requiredLabel('Price per Unit'),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _pricePerUnit = v.trim(),
                        onSaved: (v) => _pricePerUnit = v?.trim() ?? '',
                        validator:
                            (v) =>
                                v == null || v.isEmpty ? 'Enter price' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _source,
                        decoration: const InputDecoration(
                          labelText: 'Source (optional)',
                        ),
                        onChanged: (v) => _source = v.trim(),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _submit,
                        child: Text(
                          _editingStock != null ? 'Update Stock' : 'Add Stock',
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
