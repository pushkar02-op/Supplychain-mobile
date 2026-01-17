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

  bool _isLoading = false;
  int _skip = 0;
  final int _limit = 50;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadRejections(reset: true);
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
      _loadRejections(reset: true);
    }
  }

  Future<void> _loadItems() async {
    final allItems = await RejectionService.fetchItemsWithBatches();
    setState(() => _items = allItems);
  }

  Future<void> _loadRejections({bool reset = false}) async {
    if (_isLoading) return;

    if (reset) {
      setState(() {
        _skip = 0;
        _rejections.clear();
        _hasMore = true;
      });
    }

    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final result = await RejectionService.fetchRejections(
        date: date,
        itemIds: _selectedItemId != null ? [_selectedItemId!] : null,
        skip: _skip,
        limit: _limit,
      );

      final newItems = List<Map<String, dynamic>>.from(result['items']);
      final hasMore = result['has_more'] as bool;

      if (mounted) {
        setState(() {
          _rejections.addAll(newItems);
          _skip += newItems.length;
          _hasMore = hasMore;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load rejections: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDateFilter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
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
        _loadRejections(reset: true);
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

  Future<void> _handleReversal(Map<String, dynamic> rejection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reverse rejection'),
            content: Text(
              'This will restore ${rejection['quantity']} ${rejection['unit'] ?? ''} back to stock.\n\n'
              'The rejection record will remain for audit, but will be marked as reversed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Reverse',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await RejectionService.reverseRejection(rejection['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rejection reversed. Stock has been restored.'),
            ),
          );
          _loadRejections(reset: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildList() {
    if (_rejections.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No rejections recorded',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/rejection-entry'),
              icon: const Icon(Icons.add),
              label: const Text('Record a rejection'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _rejections.length + 1,
      itemBuilder: (_, index) {
        if (index == _rejections.length) {
          if (_hasMore) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                        onPressed: () => _loadRejections(),
                        child: const Text('Load More'),
                      ),
            );
          } else {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'End of list',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
        }

        final r = _rejections[index];
        final isActive = r['is_active'] ?? true;

        return Card(
          elevation: isActive ? 1 : 0,
          color: isActive ? Colors.white : Colors.grey[200],
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Row(
              children: [
                Expanded(child: Text(r['batch']['item_name'])),
                if (!isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Reversed',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            subtitle: Opacity(
              opacity: isActive ? 1.0 : 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Batch received date: ${r['batch']['received_at']}'),
                  Text('Quantity: ${r['quantity']} ${r['unit'] ?? ''}'),
                  if (r['reason'] != null && r['reason'].toString().isNotEmpty)
                    Text('Reason: ${r['reason']}'),
                  Text(
                    'Rejected At: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(r['rejection_date']))}',
                  ),
                ],
              ),
            ),
            trailing:
                isActive
                    ? IconButton(
                      icon: const Icon(Icons.restore),
                      tooltip: 'Reverse rejection',
                      onPressed: () => _handleReversal(r),
                    )
                    : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Rejections'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
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
