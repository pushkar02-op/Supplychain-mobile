import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/order_service.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrdersScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedMartFilter;
  List<String> _marts = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadMarts();
    _fetchOrders();
  }

  Future<void> _loadMarts() async {
    try {
      final list = await OrderService.fetchMartNames();
      if (mounted) setState(() => _marts = list);
    } catch (_) {}
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final orders = await OrderService.fetchOrders(
        _selectedDate,
        martName: _selectedMartFilter,
      );
      if (mounted) setState(() => _orders = orders);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(_selectedDate.year - 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchOrders();
    }
  }

  Future<void> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Order'),
            content: const Text('Confirm delete this order?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok == true) {
      await OrderService.deleteOrder(id);
      _fetchOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('DAILY ORDER')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                ),
                const SizedBox(width: 12),

                // Mart filter fills remaining space
                Expanded(
                  child: DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _selectedMartFilter,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 200,
                      width: 200, // You can adjust this as needed
                    ),
                    hint: const Text('All Marts'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Marts'),
                      ),
                      ..._marts.map(
                        (m) => DropdownMenuItem(value: m, child: Text(m)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedMartFilter = v;
                        _fetchOrders();
                      });
                    },
                  ),
                ),

                const SizedBox(width: 12),

                // Add Order button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () async {
                    final ok = await context.push('/order-entry');
                    if (ok == true) _fetchOrders();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Order'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error.isNotEmpty
                      ? Center(
                        child: Text(
                          _error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                      : _orders.isEmpty
                      ? const Center(
                        child: Text('No orders found for this date and mart'),
                      )
                      : ListView.builder(
                        itemCount: _orders.length,
                        itemBuilder: (_, i) {
                          final o = _orders[i];
                          final itemName = o['item']?['name'] ?? 'Unknown';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text('$itemName'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order: ${o['quantity_ordered']}${o['unit']}',
                                  ),
                                  Text(
                                    'Dispatched: ${o['quantity_dispatched']}${o['unit']}',
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    final ok = await context.push(
                                      '/order-entry',
                                      extra: o,
                                    );
                                    if (ok == true) _fetchOrders();
                                  } else {
                                    _confirmDelete(o['id']);
                                  }
                                },
                                itemBuilder:
                                    (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
