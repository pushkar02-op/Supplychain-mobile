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

  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  List<String> _unitOptions = [];
  List<String> _marts = [];

  Map<String, dynamic>? _editingOrder;

  @override
  void initState() {
    super.initState();
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
      'item_name': _editingOrder!['item']['name'],
      'uom': _unit,
    };

    // ⚠️ Make sure the existing unit is in our options so the dropdown can display it
    if (!_unitOptions.contains(_unit)) {
      _unitOptions = List.from(_unitOptions)..add(_unit);
    }
  }

  Future<void> _loadItemsForMart(String martName) async {
    setState(() {
      _items = [];
      _selectedItem = null;
      _unitOptions = [];
      _unit = '';
    });
    try {
      final items = await OrderService.fetchDistinctItemsForMart(martName);
      setState(() {
        _items = items;
      });
    } catch (e, st) {
      print('Error loading items: $e\n$st');
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
    print('Submit called');
    if (!_formKey.currentState!.validate() ||
        _selectedItem == null ||
        _selectedMart == null) {
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final payload = {
      'item_id': _selectedItem!['item_id'],
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
          martName: payload['mart_name'],
          orderDate: payload['order_date'],
          quantityOrdered: payload['quantity_ordered'],
          unit: payload['unit'],
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
    } on DioException catch (dioErr) {
      print('Order create error: ${dioErr.response?.data}');
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
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
                : (_marts.isEmpty)
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
                        onChanged: (m) {
                          setState(() => _selectedMart = m);
                          if (m != null) _loadItemsForMart(m);
                        },
                        validator:
                            (m) => m == null ? 'Please select a mart' : null,
                      ),
                      const SizedBox(height: 12),

                      // Item
                      DropdownSearch<Map<String, dynamic>>(
                        asyncItems: (String filter) async {
                          await Future.delayed(
                            const Duration(milliseconds: 300),
                          );
                          if (_items.isEmpty) return [];
                          if (filter.isEmpty) {
                            return _items.cast<Map<String, dynamic>>();
                          }
                          final lower = filter.toLowerCase();
                          return _items
                              .cast<Map<String, dynamic>>()
                              .where(
                                (item) => (item['item_name'] as String)
                                    .toLowerCase()
                                    .contains(lower),
                              )
                              .toList();
                        },
                        selectedItem: _selectedItem,
                        itemAsString: (item) => item['item_name'] as String,
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
                          if (item != null) {
                            setState(() {
                              _selectedItem = item;
                              _unit = item['uom'] as String;
                              _unitOptions = [_unit];
                            });
                          }
                        },
                        validator:
                            (item) =>
                                item == null ? 'Please select an item' : null,
                      ),
                      if (_selectedMart != null && _items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
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

                      // Quantity
                      TextFormField(
                        initialValue: _quantity,
                        decoration: InputDecoration(
                          label: _requiredLabel('Quantity'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
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

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        icon: const Icon(Icons.add),
                        label:
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
