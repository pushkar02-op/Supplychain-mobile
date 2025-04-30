// lib/screens/order_entry_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/order_service.dart';
import '../services/stock_service.dart';
import '../widgets/form/custom_date_picker.dart';

class OrderEntryScreen extends StatefulWidget {
  const OrderEntryScreen({super.key});

  @override
  State<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends State<OrderEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _orderDate = DateTime.now();
  Map<String, dynamic>? _selectedItem;
  String? _selectedMart;
  String _quantity = '';
  String _unit = '';
  bool _isLoading = false;
  String _error = '';

  List<dynamic> _items = [];
  List<String> _marts = [];
  List<String> _unitOptions = [];

  Map<String, dynamic>? _editingOrder;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadMarts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      _editingOrder = extra;
      _preFill();
    }
  }

  void _preFill() {
    if (_editingOrder == null) return;

    _orderDate = DateTime.parse(_editingOrder!['order_date']);
    _quantity = _editingOrder!['quantity_ordered'].toString();
    _unit = _editingOrder!['unit'] as String;
    _selectedMart = _editingOrder!['mart_name'] as String;
    _selectedItem = {
      'id': _editingOrder!['item_id'],
      'name': _editingOrder!['item']['name'],
      'default_unit': _unit,
    };

    // ⚠️ Make sure the existing unit is in our options so the dropdown can display it
    if (!_unitOptions.contains(_unit)) {
      _unitOptions = List.from(_unitOptions)..add(_unit);
    }
  }

  Future<void> _loadItems() async {
    try {
      final items = await StockService.fetchItems();
      items.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
      setState(() {
        _items = items;
        _unitOptions =
            items.map((e) => e['default_unit'] as String).toSet().toList()
              ..sort();

        // If we already have an editing unit, ensure it's included:
        if (_unit.isNotEmpty && !_unitOptions.contains(_unit)) {
          _unitOptions.add(_unit);
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _loadMarts() async {
    try {
      final marts = await OrderService.fetchMartNames();
      setState(() => _marts = marts);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null) setState(() => _orderDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _selectedItem == null ||
        _selectedMart == null) {
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final payload = {
      'item_id': _selectedItem!['id'],
      'mart_name': _selectedMart!,
      'order_date': DateFormat('yyyy-MM-dd').format(_orderDate),
      'quantity_ordered': double.parse(_quantity),
      'unit': _unit,
    };
    try {
      dynamic result;
      if (_editingOrder != null) {
        result = await OrderService.updateOrder(_editingOrder!['id'], payload);
      } else {
        result = await OrderService.createOrder(
          itemId: payload['item_id'],
          unit: payload['unit'],
          martName: payload['mart_name'],
          orderDate: payload['order_date'],
          quantityOrdered: payload['quantity_ordered'],
        );
      }

      setState(() => _isLoading = false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingOrder != null ? 'Order updated' : 'Order added',
            ),
          ),
        );
        context.pop(true);
      }
    } on DioError catch (dioErr) {
      // Backend threw HTTPException with detail {"error":..., "message":...}
      final data = dioErr.response?.data['detail'];
      setState(() {
        _error =
            (data is Map && data['message'] is String)
                ? data['message']
                : 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  Widget _requiredLabel(String text) {
    return RichText(
      text: TextSpan(
        text: text,
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
          _editingOrder != null ? 'EDIT ORDER ENTRY' : 'ADD ORDER ENTRY',
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
                : (_items.isEmpty || _marts.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // Date
                      CustomDatePicker(
                        selectedDate: _orderDate,
                        onTap: _pickDate,
                        enabled: _editingOrder == null,
                        label: _requiredLabel('Date'),
                      ),
                      const SizedBox(height: 12),

                      // Item
                      if (_editingOrder != null)
                        TextFormField(
                          initialValue: _selectedItem!['name'] as String,
                          decoration: InputDecoration(
                            label: _requiredLabel('Selected Item'),
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                          enabled: false,
                        )
                      else
                        DropdownSearch<Map<String, dynamic>>(
                          selectedItem: _selectedItem,
                          asyncItems: (filter) async {
                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );
                            if (filter.isEmpty) {
                              return _items.cast<Map<String, dynamic>>();
                            }
                            return _items
                                .cast<Map<String, dynamic>>()
                                .where(
                                  (it) => (it['name'] as String)
                                      .toLowerCase()
                                      .contains(filter.toLowerCase()),
                                )
                                .toList();
                          },
                          itemAsString: (it) => it['name'] as String,
                          onChanged: (it) {
                            setState(() {
                              _selectedItem = it;
                              _unit = it!['default_unit'] as String;
                              // ensure unitOptions now contains it
                              if (!_unitOptions.contains(_unit)) {
                                _unitOptions.add(_unit);
                              }
                            });
                          },
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              label: _requiredLabel('Item'),
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
                          validator:
                              (it) =>
                                  it == null ? 'Please select an item' : null,
                        ),
                      const SizedBox(height: 12),

                      // Unit
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
                        onChanged: (v) => setState(() => _unit = v!),
                        validator:
                            (v) => v == null || v.isEmpty ? 'Enter unit' : null,
                      ),
                      const SizedBox(height: 12),

                      // Mart
                      DropdownButtonFormField<String>(
                        value: _selectedMart,
                        decoration: InputDecoration(
                          label: _requiredLabel('Mart'),
                        ),
                        items:
                            _marts
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m),
                                  ),
                                )
                                .toList(),
                        onChanged: (m) => setState(() => _selectedMart = m),
                        validator:
                            (m) => m == null ? 'Please select a mart' : null,
                      ),
                      const SizedBox(height: 12),

                      // Quantity
                      TextFormField(
                        initialValue: _quantity,
                        decoration: InputDecoration(
                          label: _requiredLabel('Quantity'),
                        ),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => _quantity = v!.trim(),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Enter quantity'
                                    : null,
                      ),
                      const SizedBox(height: 24),

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
                                : Text(
                                  _editingOrder != null ? 'UPDATE' : 'SAVE',
                                ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
