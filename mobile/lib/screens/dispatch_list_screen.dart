import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../services/dispatch_service.dart';
import '../widgets/reversal_dialog.dart';
import '../widgets/skeleton_loader.dart';

class DispatchListScreen extends ConsumerStatefulWidget {
  const DispatchListScreen({super.key});

  @override
  ConsumerState<DispatchListScreen> createState() => _DispatchListScreenState();
}

class _DispatchListScreenState extends ConsumerState<DispatchListScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedMart;
  List<String> _marts = [];
  List<dynamic> _dispatches = [];
  bool _isLoading = false;
  String _error = '';
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    _loadMarts();
    _fetch();
  }

  Future<void> _loadMarts() async {
    try {
      final list = await DispatchService.fetchMartNames();
      setState(() => _marts = list);
    } catch (_) {}
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final list = await DispatchService.fetchDispatches(
        dispatchDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        martName: _selectedMart,
        hideFullyReversed: !_showHidden,
      );
      setState(() => _dispatches = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (d != null) {
      setState(() => _selectedDate = d);
      _fetch();
    }
  }

  Future<void> _handleReversal(int id, double currentQty) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ReversalDialog(dispatchId: id, maxQuantity: currentQty),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await DispatchService.reverseDispatch(
          id,
          result['quantity'],
          result['reason'],
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispatch reversed successfully')),
        );
        _fetch();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Dispatch'),
        actions: const [],
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Filters Row
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                  onPressed: _pickDate,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _selectedMart,
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
                      width: 200,
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
                        _selectedMart = v;
                        _fetch();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                  onPressed: () => context.push('/orders'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Toggle for Reversed
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text("Show Reversed"),
                Switch(
                  value: _showHidden,
                  onChanged: (val) {
                    setState(() {
                      _showHidden = val;
                      _fetch();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child:
                  _isLoading
                      ? const StaticSkeletonList(itemCount: 5)
                      : _error.isNotEmpty
                      ? Center(
                        // ... error view ...
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
                              'Could not load dispatches',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _fetch,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                      : _dispatches.isEmpty
                      ? Center(
                        // ... empty view ...
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No dispatches for this date',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create orders first, then dispatch',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        itemCount: _dispatches.length,
                        itemBuilder: (ctx, i) {
                          final d = _dispatches[i];

                          final batch = d['batch'] ?? {};
                          final netQty =
                              d['net_quantity'] ??
                              d['quantity']; // Fallback if missing

                          final status = d['status'] as String? ?? 'Active';
                          final isPartial = status == 'Partially Reversed';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${batch['item_name']} — $netQty ${d['unit']}',
                                      style: TextStyle(
                                        decoration:
                                            isPartial
                                                ? TextDecoration.none
                                                : null, // Maybe strikethrough if cancelled? No.
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (isPartial)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Partial',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[800],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                '${d['dispatch_date']} @ ${d['mart_name']}',
                              ),
                              trailing:
                                  (ref.watch(authProvider).value?.isAdmin ??
                                          false)
                                      ? PopupMenuButton<String>(
                                        onSelected: (v) async {
                                          if (v == 'reverse') {
                                            final double currentQty =
                                                netQty is num
                                                    ? netQty.toDouble()
                                                    : 0.0;
                                            _handleReversal(
                                              d['id'] as int,
                                              currentQty,
                                            );
                                          }
                                        },
                                        itemBuilder:
                                            (_) => const [
                                              PopupMenuItem(
                                                value: 'reverse',
                                                child: Text(
                                                  'Reverse Dispatch',
                                                  style: TextStyle(
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              ),
                                            ],
                                      )
                                      : null,
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
