import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/order_service.dart';
import '../widgets/skeleton_loader.dart';

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
      final marts = await OrderService.fetchMartList();
      setState(() {
        _marts = marts.map((mart) => mart['name'] as String).toList();
      });
    } catch (e) {
      debugPrint('Failed to load marts: $e');
    }
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
            content: const Text('Are you sure you want to delete this order?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
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

  String _getStatusText(num ordered, num dispatched) {
    if (dispatched >= ordered) return 'Fully dispatched';
    if (dispatched > 0) return 'Partially dispatched';
    return 'Not dispatched yet';
  }

  Color _getStatusColor(num ordered, num dispatched) {
    if (dispatched >= ordered) return Colors.green;
    if (dispatched > 0) return Colors.amber.shade700;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatted = DateFormat('EEEE, MMM d').format(_selectedDate);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header with semantic meaning
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isToday ? 'Today — $dateFormatted' : dateFormatted,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, size: 20),
                      onPressed: _pickDate,
                      tooltip: 'Change date',
                    ),
                  ],
                ),
                Text(
                  'Orders scheduled for this date',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Compact filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                // Mart filter chip-style
                Expanded(
                  child: DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _selectedMartFilter,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    dropdownStyleData: const DropdownStyleData(maxHeight: 200),
                    hint: const Text(
                      'All Marts',
                      style: TextStyle(fontSize: 14),
                    ),
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
              ],
            ),
          ),
          const Divider(height: 1),
          // Orders list
          Expanded(
            child:
                _isLoading
                    ? const StaticSkeletonList(itemCount: 5)
                    : _error.isNotEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _fetchOrders,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : _orders.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No orders for this date',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap + to create an order',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _fetchOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (_, i) => _buildOrderCard(_orders[i]),
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await context.push('/order-entry');
          if (ok == true) _fetchOrders();
        },
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add),
        label: const Text('Add Order'),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> o) {
    final itemName = o['item']?['name'] ?? 'Unknown';
    final martName = o['mart_name'] ?? '';
    final ordered = (o['quantity_ordered'] as num?) ?? 0;
    final dispatched = (o['quantity_dispatched'] as num?) ?? 0;
    final remaining = ordered - dispatched;
    final unit = o['unit'] ?? '';

    final statusText = _getStatusText(ordered, dispatched);
    final statusColor = _getStatusColor(ordered, dispatched);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: statusColor, width: 5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final ok = await context.push(
            '/dispatch-entry',
            extra: {
              'order_id': o['id'],
              'item_id': o['item_id'],
              'batch_id': o['batch_id'],
              'mart_name': o['mart_name'],
              'quantity_ordered': o['quantity_ordered'],
              'quantity_dispatched': o['quantity_dispatched'],
              'unit': o['unit'],
              'dispatch_date': o['order_date'],
              'item_name': o['item']?['name'],
            },
          );
          if (ok == true) _fetchOrders();
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      martName,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _quantityChip(
                          'Ordered',
                          ordered,
                          unit,
                          Colors.grey.shade200,
                        ),
                        const SizedBox(width: 8),
                        _quantityChip(
                          'Dispatched',
                          dispatched,
                          unit,
                          Colors.green.shade50,
                        ),
                        const SizedBox(width: 8),
                        _quantityChip(
                          'Remaining',
                          remaining,
                          unit,
                          remaining > 0
                              ? Colors.orange.shade50
                              : Colors.grey.shade100,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          dispatched >= ordered
                              ? Icons.check_circle
                              : dispatched > 0
                              ? Icons.autorenew
                              : Icons.schedule,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    final ok = await context.push('/order-entry', extra: o);
                    if (ok == true) _fetchOrders();
                  } else if (v == 'dispatch') {
                    final ok = await context.push(
                      '/dispatch-entry',
                      extra: {
                        'order_id': o['id'],
                        'item_id': o['item_id'],
                        'batch_id': o['batch_id'],
                        'mart_name': o['mart_name'],
                        'quantity_ordered': o['quantity_ordered'],
                        'quantity_dispatched': o['quantity_dispatched'],
                        'unit': o['unit'],
                        'dispatch_date': o['order_date'],
                        'item_name': o['item']?['name'],
                      },
                    );
                    if (ok == true) _fetchOrders();
                  } else {
                    _confirmDelete(o['id']);
                  }
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(value: 'dispatch', child: Text('Dispatch')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quantityChip(String label, num value, String unit, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}$unit',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
