import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/rejection_provider.dart';
import '../ui/widgets/agro_snack_bar.dart';
import '../ui/widgets/error_state.dart';

class RejectionListScreen extends ConsumerStatefulWidget {
  const RejectionListScreen({super.key});

  @override
  ConsumerState<RejectionListScreen> createState() =>
      _RejectionListScreenState();
}

class _RejectionListScreenState extends ConsumerState<RejectionListScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _items = [];
  int? _selectedItemId;
  List<Map<String, dynamic>> _rejections = [];

  AsyncValue<void> _itemsState = const AsyncValue.loading();
  AsyncValue<void> _rejectionsState = const AsyncValue.loading();

  int _skip = 0;
  final int _limit = 50;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadItems();
      _loadRejections(reset: true);
    });
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
    setState(() => _itemsState = const AsyncValue.loading());
    try {
      final allItems =
          await ref
              .read(rejectionListProvider.notifier)
              .fetchItemsWithBatches();
      if (mounted) {
        setState(() {
          _items = allItems;
          _itemsState = const AsyncValue.data(null);
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _itemsState = AsyncValue.error(e, st));
      }
    }
  }

  Future<void> _loadRejections({bool reset = false}) async {
    if (_rejectionsState.isLoading && !reset && _rejections.isNotEmpty) return;

    if (reset) {
      setState(() {
        _skip = 0;
        _rejections.clear();
        _hasMore = true;
        _rejectionsState = const AsyncValue.loading();
      });
    }

    if (!_hasMore) return;

    try {
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final result = await ref
          .read(rejectionListProvider.notifier)
          .fetchRejections(
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
          _rejectionsState = const AsyncValue.data(null);
        });
      }
    } catch (e, st) {
      if (mounted) {
        if (reset) {
          setState(() => _rejectionsState = AsyncValue.error(e, st));
        } else {
          // Pagination error - show snackbar instead of full error screen
          AgroSnackBar.error(context, 'Failed to load rejections: $e');
        }
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
    return _itemsState.when(
      data:
          (_) => DropdownButtonFormField<int>(
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
          ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Failed to load items: $e'),
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
        await ref
            .read(rejectionListProvider.notifier)
            .reverseRejection(rejection['id']);
        if (mounted) {
          AgroSnackBar.success(
            context,
            'Rejection reversed. Stock has been restored.',
          );
          _loadRejections(reset: true);
        }
      } catch (e) {
        if (mounted) {
          AgroSnackBar.error(context, 'Error: $e');
        }
      }
    }
  }

  Widget _buildList() {
    return _rejectionsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (e, _) => AgroErrorState.loadFailed(
            message: e.toString(),
            onRetry: () => _loadRejections(reset: true),
          ),
      data: (_) {
        if (_rejections.isEmpty) {
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
                  child: ElevatedButton(
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
                      if (r['reason'] != null &&
                          r['reason'].toString().isNotEmpty)
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
