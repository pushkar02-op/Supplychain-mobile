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

  @override
  void initState() {
    super.initState();
    _loadItems();
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
          // Build distinct unit list
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

    final qty = double.parse(_quantity);
    final price = double.parse(_pricePerUnit);

    final result = await StockService.addStockEntry(
      itemId: _selectedItem!['id'],
      receivedDate: _receivedDate!.toIso8601String().split('T')[0],
      quantity: qty,
      unit: _unit,
      pricePerUnit: price,
      source: _source.isEmpty ? null : _source,
      totalCost: qty * price,
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock entry added')));
      context.pop();
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
      appBar: AppBar(title: const Text('ADD STOCK ENTRY')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _items.isEmpty
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
                      // Date picker
                      ListTile(
                        title: Text(
                          'Date: ${_receivedDate!.toIso8601String().split('T')[0]}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 12),

                      DropdownSearch<Map<String, dynamic>>(
                        asyncItems: (String filter) async {
                          // 500ms debounce
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
                          // dialogProps: DialogProps(
                          //   insetPadding: EdgeInsets.symmetric(
                          //     horizontal: 16,
                          //     vertical: 16,
                          //   ), // Controls space around the dialog
                          //   shape: RoundedRectangleBorder(
                          //     borderRadius: BorderRadius.circular(
                          //       16,
                          //     ), // Customizing the shape
                          //   ),
                          // ),
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
                            (item) =>
                                item == null ? 'Please select an item' : null,
                      ),
                      const SizedBox(height: 12),
                      // Quantity
                      TextFormField(
                        decoration: InputDecoration(
                          label: _requiredLabel('Quantity'),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _quantity = v.trim(),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Enter quantity'
                                    : null,
                      ),
                      const SizedBox(height: 12),

                      // Unit dropdown (editable)
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
                        onChanged:
                            (v) => setState(() {
                              _unit = v ?? '';
                            }),
                        validator:
                            (v) => v == null || v.isEmpty ? 'Enter unit' : null,
                      ),
                      const SizedBox(height: 12),

                      // Price per Unit
                      TextFormField(
                        decoration: InputDecoration(
                          label: _requiredLabel('Price per Unit'),
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

                      // Source (optional)
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Source (optional)',
                        ),
                        onChanged: (v) => _source = v.trim(),
                      ),
                      const SizedBox(height: 20),

                      if (_error.isNotEmpty)
                        Text(_error, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child:
                            _isLoading
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                : const Text('SAVE'),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
