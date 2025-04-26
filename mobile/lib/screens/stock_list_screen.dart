// stock_list_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/stock_service.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _stocks = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchStocks();
  }

  Future<void> _fetchStocks() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final dateString = _selectedDate.toIso8601String().split('T')[0];
      final result = await StockService.fetchStockEntries(date: dateString);
      if (mounted) {
        setState(() {
          _stocks = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchStocks();
    }
  }

  Future<void> _confirmDelete(int stockId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Stock Entry'),
            content: const Text('Are you sure you want to delete this entry?'),
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

    if (confirmed == true) {
      await StockService.deleteStockEntry(stockId);
      _fetchStocks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('STOCK LIST')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_selectedDate.toIso8601String().split('T')[0]),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () async {
                    final result = await context.push(
                      '/stock-entry',
                      extra: null,
                    );
                    if (result == true) {
                      _fetchStocks();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Stock'),
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
                      : _stocks.isEmpty
                      ? const Center(
                        child: Text('No stock entries found for this date'),
                      )
                      : ListView.builder(
                        itemCount: _stocks.length,
                        itemBuilder: (context, index) {
                          final stock = _stocks[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text('Item: ${stock['item']['name']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Qty: ${stock['quantity']} ${stock['unit']}',
                                  ),
                                  Text(
                                    'Price: ₹${stock['price_per_unit']}/${stock['unit']}',
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    final result = await context.push(
                                      '/stock-entry',
                                      extra: stock,
                                    );
                                    if (result == true) {
                                      _fetchStocks();
                                    }
                                  } else if (value == 'delete') {
                                    _confirmDelete(stock['id']);
                                  }
                                },
                                itemBuilder:
                                    (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      const PopupMenuItem(
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
