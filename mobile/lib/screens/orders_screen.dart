import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/order_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrdersScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final orders = await OrderService.fetchOrders(_selectedDate);
      setState(() => _orders = orders);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
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
      appBar: AppBar(title: const Text('ORDER LIST')),
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
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
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
                        child: Text('No orders found for this date'),
                      )
                      : ListView.builder(
                        itemCount: _orders.length,
                        itemBuilder: (_, i) {
                          final o = _orders[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                '${o['mart_name']} – ${o['item_name']}',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Qty: ${o['quantity_ordered']}'),
                                  Text(
                                    'Dispatched: ${o['quantity_dispatched']}',
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
