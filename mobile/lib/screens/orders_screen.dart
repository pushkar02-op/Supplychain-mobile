import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/order_service.dart';
import '../ui/semantics/agro_severity.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';
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

  // PRESERVED EXACTLY: Delete confirmation dialog with destructive styling
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

  @override
  Widget build(BuildContext context) {
    final dateFormatted = DateFormat('EEEE, MMM d').format(_selectedDate);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header with semantic meaning
          Container(
            color: AgroColors.surface,
            padding: EdgeInsets.fromLTRB(
              AgroSpacing.lg,
              AgroSpacing.md,
              AgroSpacing.lg,
              AgroSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isToday ? 'Today — $dateFormatted' : dateFormatted,
                        style: AgroTypography.cardTitle.copyWith(fontSize: 18),
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
                  style: AgroTypography.caption,
                ),
              ],
            ),
          ),
          // Compact filter bar
          Container(
            color: AgroColors.surface,
            padding: EdgeInsets.fromLTRB(
              AgroSpacing.lg,
              0,
              AgroSpacing.lg,
              AgroSpacing.md,
            ),
            child: Row(
              children: [
                // Mart filter chip-style
                Expanded(
                  child: DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _selectedMartFilter,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AgroSpacing.md,
                        vertical: AgroSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AgroShapes.pillRadius,
                        borderSide: BorderSide(color: AgroColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AgroShapes.pillRadius,
                        borderSide: BorderSide(color: AgroColors.divider),
                      ),
                      filled: true,
                      fillColor: AgroColors.surfaceVariant,
                    ),
                    dropdownStyleData: const DropdownStyleData(maxHeight: 200),
                    hint: Text('All Marts', style: AgroTypography.body),
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
          Divider(height: 1, color: AgroColors.divider),
          // Orders list
          Expanded(
            child:
                _isLoading
                    ? const StaticSkeletonList(itemCount: 5)
                    : _error.isNotEmpty
                    ? AgroErrorState(
                      title: 'Failed to load orders',
                      message: _error,
                      onRetry: _fetchOrders,
                    )
                    : _orders.isEmpty
                    ? AgroEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No orders for this date',
                      message: 'Tap + to create an order',
                    )
                    : RefreshIndicator(
                      onRefresh: _fetchOrders,
                      child: ListView.builder(
                        padding: EdgeInsets.all(AgroSpacing.lg),
                        itemCount: _orders.length,
                        itemBuilder:
                            (_, i) => _OrderCard(
                              order: _orders[i],
                              onRefresh: _fetchOrders,
                              onDelete: _confirmDelete,
                            ),
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
        backgroundColor: AgroColors.success.text,
        icon: const Icon(Icons.add),
        label: const Text('Add Order'),
        heroTag: 'orders-add-fab',
      ),
    );
  }
}

/// Order card displaying order details with status-based left border.
/// Preserves all navigation and action callbacks exactly.
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onRefresh;
  final Future<void> Function(int) onDelete;

  const _OrderCard({
    required this.order,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final itemName = order['item']?['name'] ?? 'Unknown';
    final martName = order['mart_name'] ?? '';
    final ordered = (order['quantity_ordered'] as num?) ?? 0;
    final dispatched = (order['quantity_dispatched'] as num?) ?? 0;
    final remaining = ordered - dispatched;
    final unit = order['unit'] ?? '';

    // Derive status using semantic parser
    final status = AgroStatusParser.fromOrderDispatchProgress(
      ordered,
      dispatched,
    );
    final statusText = AgroStatusParser.getOrderDispatchLabel(
      ordered,
      dispatched,
    );
    final severityStyle = AgroSeverity.fromStatus(status);

    return Container(
      margin: EdgeInsets.only(bottom: AgroSpacing.md),
      decoration: BoxDecoration(
        color: AgroColors.surface,
        borderRadius: AgroShapes.containerRadius,
        border: Border(
          left: BorderSide(color: severityStyle.textColor, width: 5),
        ),
        boxShadow: [
          BoxShadow(
            color: AgroColors.divider,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        // PRESERVED EXACTLY: Dispatch navigation on card tap
        onTap: () async {
          final ok = await context.push(
            '/dispatch-entry',
            extra: {
              'order_id': order['id'],
              'item_id': order['item_id'],
              'batch_id': order['batch_id'],
              'mart_name': order['mart_name'],
              'quantity_ordered': order['quantity_ordered'],
              'quantity_dispatched': order['quantity_dispatched'],
              'unit': order['unit'],
              'dispatch_date': order['order_date'],
              'item_name': order['item']?['name'],
            },
          );
          if (ok == true) onRefresh();
        },
        borderRadius: AgroShapes.containerRadius,
        child: Padding(
          padding: EdgeInsets.all(AgroSpacing.md + 2), // 14px as before
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: AgroTypography.cardTitle.copyWith(fontSize: 15),
                    ),
                    SizedBox(height: AgroSpacing.xs / 2), // 2px
                    Text(martName, style: AgroTypography.caption),
                    SizedBox(height: AgroSpacing.sm),
                    Row(
                      children: [
                        _QuantityChip(
                          label: 'Ordered',
                          value: ordered,
                          unit: unit,
                          backgroundColor: AgroColors.surfaceVariant,
                        ),
                        SizedBox(width: AgroSpacing.sm),
                        _QuantityChip(
                          label: 'Dispatched',
                          value: dispatched,
                          unit: unit,
                          backgroundColor: AgroColors.success.background,
                        ),
                        SizedBox(width: AgroSpacing.sm),
                        _QuantityChip(
                          label: 'Remaining',
                          value: remaining,
                          unit: unit,
                          backgroundColor:
                              remaining > 0
                                  ? AgroColors.warning.background
                                  : AgroColors.surfaceVariant,
                        ),
                      ],
                    ),
                    SizedBox(height: AgroSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          dispatched >= ordered
                              ? Icons.check_circle
                              : dispatched > 0
                              ? Icons.autorenew
                              : Icons.schedule,
                          size: 16,
                          color: severityStyle.textColor,
                        ),
                        SizedBox(width: AgroSpacing.xs),
                        Text(
                          statusText,
                          style: AgroTypography.caption.copyWith(
                            fontWeight: FontWeight.w500,
                            color: severityStyle.textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // PRESERVED EXACTLY: PopupMenuButton with edit/dispatch/delete actions
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    final ok = await context.push('/order-entry', extra: order);
                    if (ok == true) onRefresh();
                  } else if (v == 'dispatch') {
                    final ok = await context.push(
                      '/dispatch-entry',
                      extra: {
                        'order_id': order['id'],
                        'item_id': order['item_id'],
                        'batch_id': order['batch_id'],
                        'mart_name': order['mart_name'],
                        'quantity_ordered': order['quantity_ordered'],
                        'quantity_dispatched': order['quantity_dispatched'],
                        'unit': order['unit'],
                        'dispatch_date': order['order_date'],
                        'item_name': order['item']?['name'],
                      },
                    );
                    if (ok == true) onRefresh();
                  } else {
                    onDelete(order['id']);
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
}

/// Quantity chip displaying a value with label.
class _QuantityChip extends StatelessWidget {
  final String label;
  final num value;
  final String unit;
  final Color backgroundColor;

  const _QuantityChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AgroSpacing.sm,
        vertical: AgroSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AgroShapes.bannerRadius,
      ),
      child: Column(
        children: [
          Text(
            '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}$unit',
            style: AgroTypography.captionEmphasis,
          ),
          Text(label, style: AgroTypography.caption.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}
