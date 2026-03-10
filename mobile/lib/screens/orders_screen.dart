import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../providers/active_mart_provider.dart';
import '../providers/order_provider.dart';
import '../ui/semantics/agro_severity.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_status_badge.dart';
import '../widgets/skeleton_loader.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(selectedDate.year - 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      await ref.read(orderListProvider.notifier).setDate(picked);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
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
      await ref.read(orderListProvider.notifier).deleteOrder(id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(orderListProvider);
    final martNames = ref.watch(
      martListProvider.select(
        (async) =>
            async.valueOrNull?.map((mart) => mart['name'] as String).toList() ??
            const <String>[],
      ),
    );
    final selectedMart = ref.watch(activeMartProvider);

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: stateAsync.when(
        loading: () => const StaticSkeletonList(itemCount: 5),
        error:
            (e, _) => AgroErrorState(
              title: 'Failed to load orders',
              message: e.toString(),
              onRetry: () => ref.read(orderListProvider.notifier).refresh(),
            ),
        data: (state) {
          final dateFormatted = DateFormat(
            'EEEE, MMM d',
          ).format(state.selectedDate);
          final isToday = DateUtils.isSameDay(
            state.selectedDate,
            DateTime.now(),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: AgroColors.surface,
                padding: const EdgeInsets.fromLTRB(
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
                            style: AgroTypography.cardTitle.copyWith(
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today, size: 20),
                          onPressed:
                              () => _pickDate(context, ref, state.selectedDate),
                          tooltip: 'Change date',
                        ),
                      ],
                    ),
                    const Text(
                      'Orders scheduled for this date',
                      style: AgroTypography.caption,
                    ),
                  ],
                ),
              ),
              Container(
                color: AgroColors.surface,
                padding: const EdgeInsets.fromLTRB(
                  AgroSpacing.lg,
                  0,
                  AgroSpacing.lg,
                  AgroSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField2<String>(
                        isExpanded: true,
                        value: selectedMart,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AgroSpacing.md,
                            vertical: AgroSpacing.sm,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AgroShapes.pillRadius,
                            borderSide: const BorderSide(
                              color: AgroColors.divider,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AgroShapes.pillRadius,
                            borderSide: const BorderSide(
                              color: AgroColors.divider,
                            ),
                          ),
                          filled: true,
                          fillColor: AgroColors.surfaceVariant,
                        ),
                        dropdownStyleData: const DropdownStyleData(
                          maxHeight: 200,
                        ),
                        hint: const Text(
                          'All Marts',
                          style: AgroTypography.body,
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Marts'),
                          ),
                          ...martNames.map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          ),
                        ],
                        onChanged:
                            (v) =>
                                ref.read(activeMartProvider.notifier).state = v,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AgroColors.divider),
              Expanded(
                child:
                    state.orders.isEmpty
                        ? const AgroEmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'No orders for this date',
                          message: 'Tap + to create an order',
                        )
                        : RefreshIndicator(
                          onRefresh:
                              () =>
                                  ref
                                      .read(orderListProvider.notifier)
                                      .refresh(),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AgroSpacing.lg),
                            itemCount: state.orders.length,
                            itemBuilder:
                                (_, i) => _OrderCard(
                                  order: state.orders[i],
                                  onDelete:
                                      (id) => _confirmDelete(context, ref, id),
                                ),
                          ),
                        ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/order-entry'),
        backgroundColor: AgroColors.success.text,
        icon: const Icon(Icons.add),
        label: const Text('Add Order'),
        heroTag: 'orders-add-fab',
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final Future<void> Function(int) onDelete;

  const _OrderCard({required this.order, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final itemName = order.itemName;
    final martName = order.martName ?? 'Unknown Mart';
    final ordered = order.quantityOrdered;
    final dispatched = order.quantityDispatched;
    final remaining = ordered - dispatched;
    final unit = order.unit;

    final status = AgroStatusParser.fromOrderDispatchProgress(
      ordered,
      dispatched,
    );
    final statusText = AgroStatusParser.getOrderDispatchLabel(
      ordered,
      dispatched,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AgroSpacing.md),
      decoration: BoxDecoration(
        color: AgroColors.surface,
        borderRadius: AgroShapes.containerRadius,
        border: Border(
          left: BorderSide(
            color: AgroSeverity.fromStatus(status).textColor,
            width: 5,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: AgroColors.divider,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.push(
            '/dispatch-entry',
            extra: {
              'order_id': order.id,
              'item_id': order.itemId,
              'mart_name': order.martName,
              'quantity_ordered': order.quantityOrdered,
              'quantity_dispatched': order.quantityDispatched,
              'unit': order.unit,
              'dispatch_date': order.orderDate.toIso8601String(),
              'item_name': order.itemName,
            },
          );
        },
        borderRadius: AgroShapes.containerRadius,
        child: Padding(
          padding: const EdgeInsets.all(AgroSpacing.md + 2),
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
                    const SizedBox(height: AgroSpacing.xs / 2),
                    Text(martName, style: AgroTypography.caption),
                    const SizedBox(height: AgroSpacing.sm),
                    Row(
                      children: [
                        _QuantityChip(
                          label: 'Ordered',
                          value: ordered,
                          unit: unit,
                          backgroundColor: AgroColors.surfaceVariant,
                        ),
                        const SizedBox(width: AgroSpacing.sm),
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
                    const SizedBox(height: AgroSpacing.sm),
                    AgroStatusBadge.compact(status: status, label: statusText),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    context.push('/order-entry', extra: order.toJson());
                  } else if (v == 'dispatch') {
                    context.push(
                      '/dispatch-entry',
                      extra: {
                        'order_id': order.id,
                        'item_id': order.itemId,
                        'mart_name': order.martName,
                        'quantity_ordered': order.quantityOrdered,
                        'quantity_dispatched': order.quantityDispatched,
                        'unit': order.unit,
                        'dispatch_date': order.orderDate.toIso8601String(),
                        'item_name': order.itemName,
                      },
                    );
                  } else {
                    onDelete(order.id);
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
      padding: const EdgeInsets.symmetric(
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
