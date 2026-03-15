import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/navigation/create_result.dart';
import '../core/ui/snackbar_service.dart';
import '../providers/rejection_provider.dart';
import '../ui/widgets/agro_error_state.dart';

class RejectionListScreen extends ConsumerStatefulWidget {
  const RejectionListScreen({super.key});

  @override
  ConsumerState<RejectionListScreen> createState() =>
      _RejectionListScreenState();
}

class _RejectionListScreenState extends ConsumerState<RejectionListScreen> {
  Future<void> _pickDate(DateTime selectedDate) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null) {
      await ref.read(rejectionListProvider.notifier).setDate(picked);
    }
  }

  Widget _buildDateFilter(RejectionListState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(DateFormat('MMM d, yyyy').format(state.selectedDate)),
          onPressed: () => _pickDate(state.selectedDate),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          icon: const Icon(Icons.add),
          label: const Text('New Reject'),
          onPressed: () async {
            final result = await context.push('/rejection-entry');
            if (result == CreateResult.created) {
              ref.invalidate(rejectionListProvider);
            }
          },
        ),
      ],
    );
  }

  Widget _buildItemFilter(RejectionListState state) {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(labelText: 'Item'),
      items:
          state.filterItems
              .map(
                (item) => DropdownMenuItem<int>(
                  value: item['id'],
                  child: Text(item['name']),
                ),
              )
              .toList(),
      // ignore: deprecated_member_use
      value: state.selectedItemId,
      onChanged: (id) => ref.read(rejectionListProvider.notifier).setItem(id),
      isExpanded: true,
    );
  }

  Widget _buildFilters(RejectionListState state) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          _buildDateFilter(state),
          const SizedBox(height: 10),
          _buildItemFilter(state),
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
          SnackbarService.showSuccess(
            context,
            'Rejection reversed. Stock has been restored.',
          );
        }
      } catch (e) {
        if (mounted) {
          SnackbarService.showError(context, 'Error: $e');
        }
      }
    }
  }

  Widget _buildList(RejectionListState state) {
    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 420,
            child: Center(
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
                    onPressed: () async {
                      final result = await context.push('/rejection-entry');
                      if (result == CreateResult.created) {
                        ref.invalidate(rejectionListProvider);
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Record a rejection'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: state.items.length + 1,
      itemBuilder: (_, index) {
        if (index == state.items.length) {
          if (state.hasMore) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed:
                    state.isLoadingMore
                        ? null
                        : () async {
                          try {
                            await ref
                                .read(rejectionListProvider.notifier)
                                .loadMore();
                          } catch (e) {
                            if (!mounted) return;
                            SnackbarService.showError(
                              context,
                              'Failed to load rejections: $e',
                            );
                          }
                        },
                child:
                    state.isLoadingMore
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Load More'),
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

        final r = state.items[index];
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
    final stateAsync = ref.watch(rejectionListProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Rejections'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => AgroErrorState.loadFailed(
              message: e.toString(),
              onRetry: () => ref.read(rejectionListProvider.notifier).refresh(),
            ),
        data: (state) => Column(
          children: [
            _buildFilters(state),
            const Divider(),
            Expanded(
              child: RefreshIndicator(
                onRefresh:
                    () async => ref.refresh(rejectionListProvider.future),
                child: _buildList(state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
