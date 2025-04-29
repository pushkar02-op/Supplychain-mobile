import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/order_service.dart';
import '../services/stock_service.dart';

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
  double _quantity = 0;

  List<dynamic> _items = [];
  List<String> _marts = [];

  Map<String, dynamic>? _editing;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadMarts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = GoRouterState.of(context).extra;
    if (args is Map<String, dynamic>) {
      _editing = args;
      _preFill();
    }
  }

  void _preFill() {
    if (_editing != null) {
      _orderDate = DateTime.parse(_editing!['order_date']);
      _quantity = _editing!['quantity_ordered'];
      _selectedMart = _editing!['mart_name'] as String;
      _selectedItem = {
        'id': _editing!['item_id'],
        'name': _editing!['item']['name'],
      };
    }
  }

  Future<void> _loadItems() async {
    final items = await StockService.fetchItems();
    items.sort((a, b) => a['name'].compareTo(b['name']));
    if (mounted) setState(() => _items = items);
  }

  Future<void> _loadMarts() async {
    final marts = await OrderService.fetchMartNames();
    if (mounted) setState(() => _marts = marts);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _orderDate = picked);
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() ||
        _selectedItem == null ||
        _selectedMart == null)
      return;
    _formKey.currentState!.save();

    final data = {
      'item_id': _selectedItem!['id'],
      'mart_name': _selectedMart!,
      'order_date': DateFormat('yyyy-MM-dd').format(_orderDate),
      'quantity_ordered': _quantity,
    };

    dynamic result;
    if (_editing != null) {
      result = await OrderService.updateOrder(_editing!['id'], data);
    } else {
      result = await OrderService.createOrder(
        itemId: data['item_id'],
        martName: data['mart_name'],
        orderDate: data['order_date'],
        quantityOrdered: data['quantity_ordered'],
      );
    }

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editing != null ? 'Order updated' : 'Order added'),
        ),
      );
      context.pop(true);
    }
  }

  Widget _required(String label) {
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
        title: Text(_editing != null ? 'EDIT ORDER' : 'ADD ORDER'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            (_items.isEmpty || _marts.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      _editing != null
                          ? TextFormField(
                            initialValue: DateFormat(
                              'yyyy-MM-dd',
                            ).format(_orderDate),
                            decoration: InputDecoration(
                              label: _required('Date'),
                            ),
                            enabled: false,
                          )
                          : ListTile(
                            title: Text(
                              'Date: ${DateFormat('yyyy-MM-dd').format(_orderDate)}',
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: _pickDate,
                          ),
                      const SizedBox(height: 12),

                      // Item dropdown
                      if (_editing != null)
                        TextFormField(
                          initialValue: _selectedItem?['name'],
                          decoration: InputDecoration(label: _required('Item')),
                          enabled: false,
                        )
                      else
                        DropdownSearch<Map<String, dynamic>>(
                          items: _items.cast<Map<String, dynamic>>(),
                          itemAsString: (i) => i['name'] as String,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              label: _required('Item'),
                            ),
                          ),
                          onChanged: (i) => _selectedItem = i,
                          validator:
                              (i) => i == null ? 'Please select an item' : null,
                        ),
                      const SizedBox(height: 12),

                      // Mart dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedMart,
                        decoration: InputDecoration(label: _required('Mart')),
                        items:
                            _marts
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _selectedMart = v),
                        validator:
                            (v) => v == null ? 'Please select a mart' : null,
                      ),
                      const SizedBox(height: 12),

                      // Quantity
                      TextFormField(
                        initialValue: '$_quantity',
                        decoration: InputDecoration(
                          label: _required('Quantity'),
                        ),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => _quantity = double.parse(v ?? '0.0'),
                        validator:
                            (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Enter quantity'
                                    : null,
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _submit,
                        child: Text(_editing != null ? 'Update Order' : 'SAVE'),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
