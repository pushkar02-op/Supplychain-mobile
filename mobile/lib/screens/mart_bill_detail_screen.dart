import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/mart_bill.dart';
import '../models/mart_bill_item.dart';
import '../providers/mart_bill_provider.dart';
import '../providers/warehouse_context_provider.dart';
import '../repositories/item_repository.dart';
import '../ui/semantics/agro_severity.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_snack_bar.dart';
import '../ui/widgets/agro_status_badge.dart';
import '../widgets/inline_item_mapping_sheet.dart';

class MartBillDetailScreen extends ConsumerStatefulWidget {
  final int billId;
  const MartBillDetailScreen({super.key, required this.billId});

  @override
  ConsumerState<MartBillDetailScreen> createState() =>
      _MartBillDetailScreenState();
}

class _MartBillDetailScreenState
    extends ConsumerState<MartBillDetailScreen> {
  // ── Local State ────────────────────────────────────────────────────────
  List<MartBillItem> _items = [];
  MartBill? _bill;
  bool _isLoading = true;
  Map<int, List<Map<String, dynamic>>> _suggestions = {};
  Map<int, int?> _pendingMappings = {};
  final Map<int, String> _searchPickNames = {};
  Set<int> _autoFilledIds = {};
  bool _isSaving = false;
  bool _showAllMapped = false;

  int get _warehouseId {
    final id = ref.read(warehouseContextProvider);
    if (id == null) throw StateError('Warehouse not selected');
    return id;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(martBillProvider.notifier);
      final results = await Future.wait([
        notifier.getBillById(widget.billId),
        notifier.fetchBillItems(widget.billId),
      ]);
      if (!mounted) return;
      setState(() {
        _bill = results[0] as MartBill;
        _items = results[1] as List<MartBillItem>;
        _isLoading = false;
      });
      await _loadSuggestions();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AgroSnackBar.error(context, e.toString());
    }
  }

  Future<void> _loadSuggestions() async {
    final bill = _bill;
    if (bill == null || bill.status == 'VERIFIED') return;
    final unresolved = _items.where((i) => i.isUnresolved).toList();
    if (unresolved.isEmpty) return;

    try {
      final suggestions = await ItemRepository().fetchBillItemSuggestions(
        warehouseId: _warehouseId,
        billId: widget.billId,
      );
      if (!mounted) return;
      final autoFilled = <int>{};
      final pending = <int, int?>{};
      for (final item in unresolved) {
        final sugs = suggestions[item.id] ?? [];
        if (sugs.isNotEmpty) {
          final conf = (sugs.first['confidence'] as num?)?.toInt() ?? 0;
          if (conf >= 80) {
            pending[item.id] =
                (sugs.first['id'] as num?)?.toInt() ??
                (sugs.first['master_item_id'] as num?)?.toInt();
            autoFilled.add(item.id);
          }
        }
      }
      setState(() {
        _suggestions = suggestions;
        _pendingMappings = pending;
        _autoFilledIds = autoFilled;
      });
    } catch (_) {
      // Suggestions are advisory — silently ignore errors
    }
  }

  Future<void> _saveAllMappings() async {
    final entries = _pendingMappings.entries
        .where((e) => e.value != null)
        .toList();
    if (entries.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final mappings = entries
          .map((e) => {'invoice_item_id': e.key, 'master_item_id': e.value!})
          .toList();
      await ItemRepository().batchMapInvoiceItems(
        warehouseId: _warehouseId,
        mappings: mappings,
      );
      if (!mounted) return;
      setState(() {
        _pendingMappings.clear();
        _searchPickNames.clear();
        _autoFilledIds.clear();
        _isSaving = false;
      });
      AgroSnackBar.success(context, '${entries.length} item(s) mapped');
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AgroSnackBar.error(context, e.toString());
    }
  }

  // ── Bill Actions ───────────────────────────────────────────────────────
  Future<void> _confirmVerify() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verify Bill'),
        content: const Text('Mark this bill as verified and lock it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(martBillProvider.notifier).verifyBill(widget.billId);
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        AgroSnackBar.error(context, e.toString());
      }
    }
  }

  Future<void> _confirmUnverify() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unlock Bill'),
        content: const Text('This will allow editing again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(martBillProvider.notifier).unverifyBill(widget.billId);
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        AgroSnackBar.error(context, e.toString());
      }
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Bill'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: AgroColors.critical.text),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(martBillProvider.notifier).deleteBill(widget.billId);
        if (!mounted) return;
        context.pop();
      } catch (e) {
        if (!mounted) return;
        AgroSnackBar.error(context, e.toString());
      }
    }
  }

  // ── Item Actions ───────────────────────────────────────────────────────
  Future<void> _confirmDeleteItem(int itemId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Remove this item from the bill?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: AgroColors.critical.text),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(martBillProvider.notifier).deleteBillItem(itemId);
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        AgroSnackBar.error(context, e.toString());
      }
    }
  }

  Future<void> _showEditItemDialog(MartBillItem item) async {
    final qtyCtrl =
        TextEditingController(text: item.quantity.toStringAsFixed(2));
    final priceCtrl =
        TextEditingController(text: item.price.toStringAsFixed(2));
    final totalCtrl =
        TextEditingController(text: item.total.toStringAsFixed(2));

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item.itemName, style: AgroTypography.cardTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Quantity', isDense: true),
            ),
            const SizedBox(height: AgroSpacing.sm),
            TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Price', isDense: true),
            ),
            const SizedBox(height: AgroSpacing.sm),
            TextField(
              controller: totalCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Total', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref.read(martBillProvider.notifier).updateBillItem(item.id, {
          'quantity': double.tryParse(qtyCtrl.text) ?? item.quantity,
          'price': double.tryParse(priceCtrl.text) ?? item.price,
          'total': double.tryParse(totalCtrl.text) ?? item.total,
        });
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        AgroSnackBar.error(context, e.toString());
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bill = _bill;
    final isVerified = bill?.status == 'VERIFIED';
    final isNeedsReview = bill?.status == 'NEEDS_REVIEW';
    final unresolved = _items.where((i) => i.isUnresolved).toList();
    final mapped = _items.where((i) => !i.isUnresolved).toList();
    final canVerify = isNeedsReview && unresolved.isEmpty;

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Bill Details'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 0,
        actions: [
          if (bill != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'pdf') {
                  context.push('/pdf-viewer', extra: widget.billId);
                } else if (v == 'delete') {
                  _confirmDelete();
                } else if (v == 'unlock') {
                  _confirmUnverify();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'pdf', child: Text('View PDF')),
                if (isVerified)
                  const PopupMenuItem(
                      value: 'unlock', child: Text('Unlock')),
                if (!isVerified)
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style:
                            TextStyle(color: AgroColors.critical.text)),
                  ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : bill == null
              ? const Center(child: Text('Bill not found'))
              : _buildBody(
                  bill, unresolved, mapped, canVerify, isVerified),
    );
  }

  Widget _buildBody(
    MartBill bill,
    List<MartBillItem> unresolved,
    List<MartBillItem> mapped,
    bool canVerify,
    bool isVerified,
  ) {
    final severity = AgroSeverity.fromBillStatus(bill.status);
    final hasPending = _pendingMappings.values.any((v) => v != null);
    final displayMapped =
        _showAllMapped ? mapped : mapped.take(3).toList();

    return CustomScrollView(
      slivers: [
        // ── Header Card ──
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(AgroSpacing.md),
            decoration: BoxDecoration(
              color: AgroColors.surface,
              borderRadius: AgroShapes.containerRadius,
              border: Border(
                  left: BorderSide(width: 5, color: severity.textColor)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            padding: const EdgeInsets.all(AgroSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        bill.martName ?? 'Unknown Mart',
                        style: AgroTypography.cardTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AgroStatusBadge.fromBillStatus(bill.status),
                  ],
                ),
                if (bill.invoiceDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy')
                        .format(DateTime.parse(bill.invoiceDate!)),
                    style: AgroTypography.caption,
                  ),
                ],
                const SizedBox(height: AgroSpacing.sm),
                // Metrics row
                Row(
                  children: [
                    _Metric(
                        label: 'Total',
                        value: '₹${bill.totalAmount.toStringAsFixed(2)}'),
                    const SizedBox(width: AgroSpacing.lg),
                    _Metric(label: 'Items', value: '${_items.length}'),
                    const SizedBox(width: AgroSpacing.lg),
                    _Metric(
                      label: 'Unresolved',
                      value: '${unresolved.length}',
                      valueColor: unresolved.isNotEmpty
                          ? AgroColors.warning.text
                          : null,
                    ),
                    const SizedBox(width: AgroSpacing.lg),
                    _Metric(
                      label: 'Mapped',
                      value: '${mapped.length}',
                      valueColor:
                          mapped.isNotEmpty ? AgroColors.success.text : null,
                    ),
                  ],
                ),
                if (bill.filePath != null) ...[
                  const SizedBox(height: AgroSpacing.sm),
                  const Divider(height: 1, color: AgroColors.divider),
                  const SizedBox(height: AgroSpacing.sm),
                  GestureDetector(
                    onTap: () =>
                        context.push('/pdf-viewer', extra: widget.billId),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined,
                            size: 16, color: AgroColors.primary),
                        const SizedBox(width: AgroSpacing.xs),
                        Expanded(
                          child: Text(
                            bill.filePath!.split('/').last,
                            style: AgroTypography.caption.copyWith(
                              color: AgroColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Action Buttons ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AgroSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ActionTile(
                        icon: isVerified
                            ? Icons.verified_outlined
                            : Icons.check_circle_outline,
                        label: isVerified ? 'Verified' : 'Verify',
                        subtitle: !isVerified && unresolved.isNotEmpty
                            ? '${unresolved.length} unresolved'
                            : null,
                        color: AgroColors.success.text,
                        background: AgroColors.success.background,
                        enabled: canVerify || isVerified,
                        onTap:
                            isVerified ? null : canVerify ? _confirmVerify : null,
                      ),
                    ),
                    const SizedBox(width: AgroSpacing.sm),
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        color: AgroColors.critical.text,
                        background: AgroColors.critical.background,
                        enabled: !isVerified,
                        onTap: isVerified ? null : _confirmDelete,
                      ),
                    ),
                  ],
                ),
                if (isVerified) ...[
                  const SizedBox(height: AgroSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: _ActionTile(
                      icon: Icons.inventory_2_outlined,
                      label: 'Generate Stock',
                      subtitle: '${mapped.length} items ready',
                      color: AgroColors.info.text,
                      background: AgroColors.info.background,
                      enabled: mapped.isNotEmpty,
                      onTap: mapped.isNotEmpty
                          ? () => context.push(
                              '/bill-stock-preview/${widget.billId}')
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Batch Save Bar ──
        if (hasPending)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(
                  AgroSpacing.md, AgroSpacing.sm, AgroSpacing.md, 0),
              padding: const EdgeInsets.all(AgroSpacing.sm + 2),
              decoration: BoxDecoration(
                color: AgroColors.info.background,
                borderRadius: AgroShapes.bannerRadius,
                border: Border.all(color: AgroColors.info.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 16, color: AgroColors.info.text),
                  const SizedBox(width: AgroSpacing.sm),
                  Expanded(
                    child: Text(
                      '${_pendingMappings.values.where((v) => v != null).length} mapping(s) ready'
                      '  ·  ${_autoFilledIds.length} auto-filled',
                      style: AgroTypography.caption
                          .copyWith(color: AgroColors.info.text),
                    ),
                  ),
                  if (_isSaving)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    TextButton(
                      onPressed: _saveAllMappings,
                      child: const Text('Save All'),
                    ),
                ],
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: AgroSpacing.sm)),

        // ── Unresolved Section ──
        if (unresolved.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              dotColor: AgroColors.warning.text,
              label: 'UNRESOLVED ITEMS',
              count: unresolved.length,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _buildUnresolvedCard(unresolved[i]),
              childCount: unresolved.length,
            ),
          ),
        ],

        // ── Mapped Section ──
        if (mapped.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              dotColor: AgroColors.success.text,
              label: 'MAPPED ITEMS',
              count: mapped.length,
              trailing: mapped.length > 3
                  ? TextButton(
                      onPressed: () =>
                          setState(() => _showAllMapped = !_showAllMapped),
                      child: Text(_showAllMapped ? 'Show less' : 'Show all'),
                    )
                  : null,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _buildMappedCard(displayMapped[i]),
              childCount: displayMapped.length,
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: AgroSpacing.xl)),
      ],
    );
  }

  Widget _buildUnresolvedCard(MartBillItem item) {
    final sugs = _suggestions[item.id] ?? [];
    final pending = _pendingMappings[item.id];

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AgroSpacing.md, 0, AgroSpacing.md, AgroSpacing.sm),
      decoration: BoxDecoration(
        color: AgroColors.surface,
        borderRadius: AgroShapes.containerRadius,
        border: Border.all(color: AgroColors.warning.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AgroSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.itemName,
                    style:
                        AgroTypography.body.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('₹${item.total.toStringAsFixed(2)}',
                    style: AgroTypography.captionEmphasis),
              ],
            ),
            Text(
              '${item.quantity} ${item.uom} × ₹${item.price.toStringAsFixed(2)}'
              '${item.itemCode != null ? '  ·  ${item.itemCode}' : ''}',
              style: AgroTypography.caption,
            ),
            const SizedBox(height: AgroSpacing.sm),
            if (sugs.isNotEmpty)
              _buildSuggestionBlock(item, sugs, pending)
            else
              _buildNoSuggestionBlock(item),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionBlock(
    MartBillItem item,
    List<Map<String, dynamic>> sugs,
    int? pending,
  ) {
    final top = sugs.first;
    final conf = (top['confidence'] as num?)?.toInt() ?? 0;
    final topId = (top['id'] as num?)?.toInt() ??
        (top['master_item_id'] as num?)?.toInt() ??
        0;
    final isHighConf = conf >= 80;
    final bgColor = isHighConf
        ? AgroColors.success.background
        : AgroColors.warning.background;
    final borderColor =
        isHighConf ? AgroColors.success.border : AgroColors.warning.border;
    final textColor =
        isHighConf ? AgroColors.success.text : AgroColors.warning.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AgroSpacing.sm),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AgroShapes.bannerRadius,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Best match · $conf%',
                      style: AgroTypography.caption.copyWith(color: textColor),
                    ),
                    Text(
                      top['name'] as String? ?? '',
                      style: AgroTypography.body,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AgroSpacing.sm),
              if (pending != null && pending != topId)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AgroSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: AgroColors.info.background,
                    borderRadius: AgroShapes.bannerRadius,
                    border: Border.all(color: AgroColors.info.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: AgroColors.info.text),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _searchPickNames[item.id] ?? 'Selected',
                          style: AgroTypography.caption.copyWith(
                            color: AgroColors.info.text,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else if (pending == topId)
                Icon(Icons.check_circle, size: 20, color: AgroColors.success.text)
              else if (isHighConf)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AgroColors.success.text,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AgroSpacing.sm, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () =>
                      setState(() => _pendingMappings[item.id] = topId),
                  child: const Text('Map'),
                )
              else
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AgroColors.warning.text,
                    side: BorderSide(color: AgroColors.warning.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AgroSpacing.sm, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () =>
                      setState(() => _pendingMappings[item.id] = topId),
                  child: const Text('Map'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _openSearchSheet(item),
          child: Text(
            pending != null && pending != topId
                ? 'Change selection'
                : '${sugs.length > 1 ? '${sugs.length - 1} more · ' : ''}Search manually',
            style: AgroTypography.caption.copyWith(
              color: AgroColors.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoSuggestionBlock(MartBillItem item) {
    return Row(
      children: [
        const Text('No suggestions', style: AgroTypography.caption),
        const SizedBox(width: AgroSpacing.sm),
        GestureDetector(
          onTap: () => _openSearchSheet(item),
          child: Text(
            'Search manually',
            style: AgroTypography.caption.copyWith(
              color: AgroColors.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSearchSheet(MartBillItem item) async {
    final result = await InlineItemMappingSheet.showForSelection(
      context,
      billId: widget.billId,
    );
    if (result != null) {
      setState(() {
        _pendingMappings[item.id] = (result['id'] as num?)?.toInt();
        _searchPickNames[item.id] = result['name'] as String? ?? '';
        _autoFilledIds.remove(item.id);
      });
    }
  }

  Widget _buildMappedCard(MartBillItem item) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AgroSpacing.md, 0, AgroSpacing.md, AgroSpacing.sm),
      decoration: BoxDecoration(
        color: AgroColors.surface,
        borderRadius: AgroShapes.containerRadius,
        border: Border.all(color: AgroColors.divider),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.check_circle_outline,
            color: AgroColors.success.text, size: 20),
        title: Text(item.itemName, style: AgroTypography.body),
        subtitle: Text(
          '${item.quantity} ${item.uom} × ₹${item.price.toStringAsFixed(2)}',
          style: AgroTypography.caption,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('₹${item.total.toStringAsFixed(2)}',
                style: AgroTypography.captionEmphasis),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _showEditItemDialog(item);
                if (v == 'delete') _confirmDeleteItem(item.id);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Metric({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AgroTypography.captionEmphasis.copyWith(
            fontSize: 16,
            color: valueColor ?? AgroColors.textPrimary,
          ),
        ),
        Text(label, style: AgroTypography.caption),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final Color background;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.background,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AgroSpacing.md, vertical: AgroSpacing.sm),
          decoration: BoxDecoration(
            color: background,
            borderRadius: AgroShapes.containerRadius,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AgroSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AgroTypography.caption.copyWith(
                        color: color, fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: AgroTypography.caption.copyWith(color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final Color dotColor;
  final String label;
  final int count;
  final Widget? trailing;

  const _SectionHeader({
    required this.dotColor,
    required this.label,
    required this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AgroSpacing.md, AgroSpacing.sm, AgroSpacing.md, AgroSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: AgroSpacing.xs),
          Text(
            '$label  ($count)',
            style: AgroTypography.caption.copyWith(
              color: dotColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
