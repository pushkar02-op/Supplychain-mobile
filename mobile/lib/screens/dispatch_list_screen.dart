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
      if (mounted) setState(() => _marts = list);
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
      if (mounted) setState(() => _dispatches = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _handleReversal({
    required int id,
    required double currentQty,
    required String itemName,
    required String martName,
    required String dispatchDate,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (_) => ReversalDialog(
            dispatchId: id,
            maxQuantity: currentQty,
            itemName: itemName,
            martName: martName,
            dispatchDate: dispatchDate,
          ),
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

  String get _dateHeader {
    if (DateUtils.isSameDay(_selectedDate, DateTime.now())) {
      return 'Today — ${DateFormat('EEEE, MMM d').format(_selectedDate)}';
    }
    return DateFormat('EEEE, MMM d').format(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    // Phase F7.3: Auth-based user permission (no local storage logic)
    final canReverse = ref.watch(authProvider).value != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Dispatch Log'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: Column(
        children: [
          // Header / Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: _pickDate,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _dateHeader,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Operational Log',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField2<String>(
                        isExpanded: true,
                        value: _selectedMart,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 8,
                          ),
                          fillColor: Colors.grey[100],
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        dropdownStyleData: const DropdownStyleData(
                          maxHeight: 200,
                        ),
                        hint: const Text(
                          'All Marts',
                          style: TextStyle(fontSize: 14),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'All Marts',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          ..._marts.map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                m,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Show Reversed',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: _showHidden,
                        onChanged: (val) {
                          setState(() {
                            _showHidden = val;
                            _fetch();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // List Body
          Expanded(
            child:
                _isLoading
                    ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: StaticSkeletonList(itemCount: 5),
                    )
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No dispatches logged',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use "Dispatch Order" to start.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 80, // Space for FAB
                      ),
                      itemCount:
                          (_dispatches.length >= 100)
                              ? _dispatches.length + 1
                              : _dispatches.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        // Footer awareness text
                        if (i == _dispatches.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'Showing first 100 dispatches.\nUse filters to narrow results.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          );
                        }

                        final d = _dispatches[i];
                        final batch = d['batch'] ?? {};
                        final netQty = d['net_quantity'] ?? d['quantity'];
                        final status = d['status'] as String? ?? 'Active';
                        final isPartial = status == 'Partially Reversed';
                        final isReversed = status == 'Reversed';

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: null, // No detail view for now
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Leading quantity circle
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color:
                                          isReversed
                                              ? Colors.grey[100]
                                              : Colors.blue[50],
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${(netQty as num).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isReversed
                                                ? Colors.grey
                                                : Colors.blue[800],
                                        decoration:
                                            isReversed
                                                ? TextDecoration.lineThrough
                                                : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Main Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          batch['item_name'] ?? 'Unknown Item',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '@ ${d['mart_name']}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (isPartial) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[50],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.orange.shade100,
                                              ),
                                            ),
                                            child: Text(
                                              'Partially Reversed',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.orange[800],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Actions (Admin / Auth guarded visually)
                                  if (canReverse && !isReversed)
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: Colors.grey[400],
                                      ),
                                      onSelected: (v) {
                                        if (v == 'reverse') {
                                          _handleReversal(
                                            id: d['id'],
                                            currentQty:
                                                (netQty as num).toDouble(),
                                            itemName:
                                                batch['item_name'] ??
                                                'Unknown Item',
                                            martName: d['mart_name'] ?? '',
                                            dispatchDate:
                                                d['dispatch_date'] ?? '',
                                          );
                                        }
                                      },
                                      itemBuilder:
                                          (_) => const [
                                            PopupMenuItem(
                                              value: 'reverse',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.history,
                                                    size: 18,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Reverse Dispatch',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/orders'),
        icon: const Icon(Icons.local_shipping),
        label: const Text('Dispatch Order'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
    );
  }
}
