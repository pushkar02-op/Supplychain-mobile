import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/rejection_service.dart';

class RejectionListScreen extends StatefulWidget {
  const RejectionListScreen({super.key});

  @override
  State<RejectionListScreen> createState() => _RejectionListScreenState();
}

class _RejectionListScreenState extends State<RejectionListScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _items = [];
  int? _selectedItemId;
  List<Map<String, dynamic>> _rejections = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadRejections();
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
      _loadRejections();
    }
  }

  Future<void> _loadItems() async {
    final allItems = await RejectionService.fetchItemsWithBatches();
    setState(() => _items = allItems);
  }

  Future<void> _loadRejections() async {
    final date =
        _selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
            : null;

    final data = await RejectionService.fetchRejections(
      date: date,
      itemIds: _selectedItemId != null ? [_selectedItemId!] : null,
    );

    setState(() => _rejections = data);
  }

  Widget _buildDateFilter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
          onPressed: _pickDate,
        ),
        const SizedBox(width: 12),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          icon: const Icon(Icons.add),
          label: const Text('New Reject'),
          onPressed: () => context.push('/rejection-entry'),
        ),
      ],
    );
  }

  Widget _buildItemFilter() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(labelText: 'Item'),
      items:
          _items
              .map(
                (item) => DropdownMenuItem<int>(
                  value: item['id'],
                  child: Text(item['name']),
                ),
              )
              .toList(),
      value: _selectedItemId,
      onChanged: (id) {
        setState(() => _selectedItemId = id);
        _loadRejections();
      },
      isExpanded: true,
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          _buildDateFilter(),
          const SizedBox(height: 10),
          _buildItemFilter(),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_rejections.isEmpty) {
      return const Center(child: Text('No rejections found.'));
    }

    return ListView.builder(
      itemCount: _rejections.length,
      itemBuilder: (_, index) {
        final r = _rejections[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(r['batch']['item_name']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Batch received date: ${r['batch']['received_at']}'),
                Text('Quantity: ${r['quantity']}'),
                if (r['reason'] != null && r['reason'].toString().isNotEmpty)
                  Text('reason: ${r['reason']}'),
                Text(
                  'Rejected At: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(r['rejection_date']))}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejection Records')),
      body: Column(
        children: [
          _buildFilters(),
          const Divider(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }
}
