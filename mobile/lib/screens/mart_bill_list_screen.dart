import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/mart_bill.dart';
import '../models/mart_bill_item.dart';
import '../providers/active_mart_provider.dart';
import '../providers/mart_bill_provider.dart';
import '../providers/warehouse_context_provider.dart';
import '../repositories/item_repository.dart';
import '../widgets/inline_item_mapping_sheet.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_snack_bar.dart';
import '../ui/widgets/agro_status_badge.dart';

class MartBillListScreen extends ConsumerWidget {
  const MartBillListScreen({super.key});

  Future<void> _pickFiles(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final pdfPaths =
        result.files
            .where(
              (file) =>
                  file.path != null &&
                  file.path!.toLowerCase().endsWith('.pdf'),
            )
            .map((file) => file.path!)
            .toList();
    ref.read(martBillProvider.notifier).setPickedPaths(pdfPaths);
  }

  Future<void> _uploadFiles(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(martBillProvider.notifier).uploadBills();
    } catch (e) {
      if (!context.mounted) return;
      AgroSnackBar.error(context, e.toString());
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    WidgetRef ref,
    DateTime? selectedDate,
  ) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null) {
      await ref.read(martBillProvider.notifier).setDate(picked);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int billId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Mart Bill'),
            content: const Text('Are you sure?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
    );
    if (ok == true) {
      await ref.read(martBillProvider.notifier).deleteBill(billId);
    }
  }

  Future<void> _showEditItemDialog(
    BuildContext context,
    WidgetRef ref,
    MartBillItem item,
  ) async {
    final qtyController = TextEditingController(
      text: item.quantity.toString(),
    );
    final priceController = TextEditingController(
      text: item.price.toString(),
    );
    final totalController = TextEditingController();

    void calculateTotal() {
      final qty = double.tryParse(qtyController.text) ?? 0;
      final price = double.tryParse(priceController.text) ?? 0;
      totalController.text = (qty * price).toStringAsFixed(2);
    }

    calculateTotal();
    qtyController.addListener(calculateTotal);
    priceController.addListener(calculateTotal);

    // ignore: use_build_context_synchronously
    await showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Edit Bill Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                TextField(
                  controller: totalController,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Total'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final qty = double.tryParse(qtyController.text);
                  final price = double.tryParse(priceController.text);
                  final total = double.tryParse(totalController.text);
                  if (qty == null || price == null || total == null) {
                    AgroSnackBar.error(context, 'Invalid input');
                    return;
                  }

                  await ref.read(martBillProvider.notifier).updateBillItem(
                    item.id,
                    {'quantity': qty, 'price': price, 'total': total},
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(martBillProvider);
    final marts = ref.watch(
      martListProvider.select(
        (async) =>
            async.valueOrNull?.map((m) => m['name'] as String).toList() ??
            const <String>[],
      ),
    );
    final selectedMart = ref.watch(activeMartProvider);

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Mart Bills'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Upload Mart Bill',
            onPressed: () => _pickFiles(ref),
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.toString(),
                    style: TextStyle(color: AgroColors.critical.text),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AgroSpacing.md),
                  ElevatedButton.icon(
                    onPressed:
                        () => ref.read(martBillProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
        data: (state) {
          return Padding(
            padding: const EdgeInsets.all(AgroSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          () => _selectDate(context, ref, state.selectedDate),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        state.selectedDate == null
                            ? 'All Dates'
                            : DateFormat(
                              'yyyy-MM-dd',
                            ).format(state.selectedDate!),
                      ),
                    ),
                    const SizedBox(width: AgroSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField2<String>(
                        isExpanded: true,
                        value: selectedMart,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AgroSpacing.md,
                            vertical: AgroSpacing.sm + 2,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        dropdownStyleData: const DropdownStyleData(
                          maxHeight: 200,
                          width: 200,
                        ),
                        hint: const Text('All Marts'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Marts'),
                          ),
                          ...marts.map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          ),
                        ],
                        onChanged:
                            (v) =>
                                ref.read(activeMartProvider.notifier).state = v,
                      ),
                    ),
                    const SizedBox(width: AgroSpacing.md),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                        ),
                        onSubmitted:
                            (v) => ref
                                .read(martBillProvider.notifier)
                                .setSearch(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AgroSpacing.md),
                if (state.pickedPaths.isNotEmpty)
                  _UploadFormCard(
                    pickedPaths: state.pickedPaths,
                    uploading: state.isUploading,
                    onCancel:
                        () => ref
                            .read(martBillProvider.notifier)
                            .setPickedPaths(const []),
                    onUpload: () => _uploadFiles(context, ref),
                  ),
                if (state.uploadResults.isNotEmpty)
                  _UploadResultsCard(
                    uploadResults: state.uploadResults,
                    onDismiss:
                        () =>
                            ref
                                .read(martBillProvider.notifier)
                                .clearUploadResults(),
                    onAddMore: () async {
                      ref.read(martBillProvider.notifier).clearUploadResults();
                      await _pickFiles(ref);
                    },
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.refresh(martBillProvider.future),
                    child: _buildBillList(context, ref, state),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillList(
    BuildContext context,
    WidgetRef ref,
    MartBillState state,
  ) {
    if (state.bills.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 420,
            child: AgroEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No mart bills found',
              actionLabel: 'Upload your first bill',
              onAction: () => _pickFiles(ref),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        top: AgroSpacing.md,
        bottom: AgroSpacing.xl,
      ),
      itemCount: state.bills.length + (state.hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == state.bills.length) {
          return Padding(
            padding: const EdgeInsets.all(AgroSpacing.lg),
            child: Center(
              child:
                  state.isLoadingMore
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                        onPressed:
                            () =>
                                ref.read(martBillProvider.notifier).loadMore(),
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('Load More'),
                      ),
            ),
          );
        }

        final bill = state.bills[i];
        return _BillCard(
          bill: bill,
          warehouseId: ref.watch(warehouseContextProvider),
          onDelete: (id) => _confirmDelete(context, ref, id),
          onEditItem: (item) => _showEditItemDialog(context, ref, item),
          onVerify: (id) => ref.read(martBillProvider.notifier).verifyBill(id),
          onUnverify:
              (id) => ref.read(martBillProvider.notifier).unverifyBill(id),
          onFetchItems:
              (id) => ref.read(martBillProvider.notifier).fetchBillItems(id),
          onDeleteItem:
              (id) => ref.read(martBillProvider.notifier).deleteBillItem(id),
          onRefresh: () => ref.read(martBillProvider.notifier).refresh(),
        );
      },
    );
  }
}

class _UploadFormCard extends StatelessWidget {
  final List<String> pickedPaths;
  final bool uploading;
  final VoidCallback onCancel;
  final VoidCallback onUpload;

  const _UploadFormCard({
    required this.pickedPaths,
    required this.uploading,
    required this.onCancel,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AgroSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: AgroShapes.containerRadius),
      child: Padding(
        padding: const EdgeInsets.all(AgroSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Selected Files', style: AgroTypography.cardTitle),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel Upload',
                  onPressed: onCancel,
                ),
              ],
            ),
            const SizedBox(height: AgroSpacing.sm),
            ...pickedPaths.map(
              (p) => Text('* ${p.split('/').last}', style: AgroTypography.body),
            ),
            const SizedBox(height: AgroSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon:
                    uploading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AgroColors.surface,
                          ),
                        )
                        : const Icon(Icons.cloud_upload),
                label: const Text('Upload'),
                onPressed: uploading ? null : onUpload,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadResultsCard extends StatelessWidget {
  final List<Map<String, dynamic>> uploadResults;
  final VoidCallback onDismiss;
  final VoidCallback onAddMore;

  const _UploadResultsCard({
    required this.uploadResults,
    required this.onDismiss,
    required this.onAddMore,
  });

  Widget? _buildUploadSubtitle(Map<String, dynamic> result) {
    final unmapped = result['unmapped_items'];
    if (unmapped is List && unmapped.isNotEmpty) {
      return Text(
        '${unmapped.length} unresolved item${unmapped.length == 1 ? '' : 's'}',
        style: TextStyle(color: AgroColors.warning.text),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AgroSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: AgroShapes.containerRadius),
      child: Padding(
        padding: const EdgeInsets.all(AgroSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Upload Results', style: AgroTypography.cardTitle),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Dismiss Results',
                  onPressed: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: AgroSpacing.sm),
            for (final result in uploadResults)
              ListTile(
                dense: true,
                leading: Icon(
                  result['success'] == true ? Icons.check_circle : Icons.error,
                  color:
                      result['success'] == true
                          ? AgroColors.success.text
                          : AgroColors.critical.text,
                ),
                title: Text(result['filename'] ?? 'Unnamed file'),
                subtitle: result['success'] == true
                    ? _buildUploadSubtitle(result)
                    : Text(
                        result['error'] ?? 'Unknown error',
                        style: TextStyle(color: AgroColors.critical.text),
                      ),
              ),
            const SizedBox(height: AgroSpacing.md),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add More Files'),
                onPressed: onAddMore,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillCard extends StatefulWidget {
  final MartBill bill;
  final int? warehouseId;
  final Future<void> Function(int) onDelete;
  final Future<void> Function(MartBillItem) onEditItem;
  final Future<void> Function(int) onVerify;
  final Future<void> Function(int) onUnverify;
  final Future<List<MartBillItem>> Function(int) onFetchItems;
  final Future<void> Function(int) onDeleteItem;
  final VoidCallback onRefresh;

  const _BillCard({
    required this.bill,
    required this.warehouseId,
    required this.onDelete,
    required this.onEditItem,
    required this.onVerify,
    required this.onUnverify,
    required this.onFetchItems,
    required this.onDeleteItem,
    required this.onRefresh,
  });

  @override
  State<_BillCard> createState() => _BillCardState();
}

class _BillCardState extends State<_BillCard> {
  final _repo = ItemRepository();

  Map<int, int?> _pendingMappings = {};
  Map<int, List<Map<String, dynamic>>> _suggestions = {};
  Map<int, String> _searchPickNames = {}; // billItemId -> name from search
  Set<int> _autoFilledIds = {};
  bool _suggestionsLoaded = false;
  bool _isSaving = false;

  void _showVerifyBlockedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cannot Verify'),
        content: Text(
          '${widget.bill.unresolvedCount} item${widget.bill.unresolvedCount == 1 ? '' : 's'} unresolved. Resolve them before verifying.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSuggestions() async {
    if (_suggestionsLoaded || widget.warehouseId == null) return;

    try {
      final data = await _repo.fetchBillItemSuggestions(
        warehouseId: widget.warehouseId!,
        billId: widget.bill.id,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = data;
        _autoFilledIds = {};
        for (final entry in data.entries) {
          if (entry.value.isNotEmpty) {
            final top = entry.value.first;
            final confidence = (top['confidence'] as num?) ?? 0;
            if (confidence >= 80) {
              final itemId = (top['id'] as num).toInt();
              _pendingMappings[entry.key] = itemId;
              _autoFilledIds.add(entry.key);
            }
          }
        }
        _suggestionsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _suggestionsLoaded = true);
    }
  }

  void _clearState() {
    setState(() {
      _pendingMappings = {};
      _suggestions = {};
      _searchPickNames = {};
      _autoFilledIds = {};
      _suggestionsLoaded = false;
    });
  }

  Future<void> _saveAllMappings() async {
    if (_isSaving || widget.warehouseId == null) return;

    final mappings = _pendingMappings.entries
        .where((e) => e.value != null)
        .map((e) => {
              'invoice_item_id': e.key,
              'master_item_id': e.value!,
            })
        .toList();

    if (mappings.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final result = await _repo.batchMapInvoiceItems(
        warehouseId: widget.warehouseId!,
        mappings: mappings,
      );
      if (!mounted) return;
      final count = (result['mapped_count'] as num?) ?? 0;
      _clearState();
      widget.onRefresh();
      AgroSnackBar.success(
        context,
        '$count item${count == 1 ? '' : 's'} mapped successfully',
      );
    } catch (e) {
      if (!mounted) return;
      AgroSnackBar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _suggestionLabel(Map<String, dynamic> s) {
    final name = s['name'] ?? '';
    final confidence = (s['confidence'] as num?)?.toInt();
    return confidence != null ? '$name ($confidence%)' : name;
  }

  Widget _buildMappingDropdown(MartBillItem item) {
    final itemSuggestions = _suggestions[item.id] ?? [];
    final currentValue = _pendingMappings[item.id];

    // Check if the selected value exists in suggestions
    final suggestionIds =
        itemSuggestions.map((s) => (s['id'] as num).toInt()).toSet();
    final isSearchPick =
        currentValue != null && !suggestionIds.contains(currentValue);

    return DropdownButton<int>(
      value: currentValue,
      hint: const Text('Select', style: TextStyle(fontSize: 12)),
      isExpanded: true,
      isDense: true,
      style: const TextStyle(fontSize: 12, color: Colors.black87),
      items: [
        if (itemSuggestions.isEmpty && !isSearchPick)
          const DropdownMenuItem<int>(
            enabled: false,
            value: -2,
            child: Text('No suggestions', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        // If the current value came from search and isn't in suggestions, add it
        if (isSearchPick)
          DropdownMenuItem<int>(
            value: currentValue,
            child: Text(
              _searchPickNames[item.id] ?? 'Item #$currentValue',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ...itemSuggestions.map((s) {
          final id = (s['id'] as num).toInt();
          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              _suggestionLabel(s),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
        const DropdownMenuItem<int>(
          value: -1,
          child: Text('Search...', style: TextStyle(fontStyle: FontStyle.italic)),
        ),
      ],
      onChanged: (value) async {
        if (value == -1) {
          final result = await InlineItemMappingSheet.showForSelection(
            context,
            billId: widget.bill.id,
          );
          if (result != null && mounted) {
            final selectedId = result['id'] as int;
            setState(() {
              _pendingMappings[item.id] = selectedId;
              _searchPickNames[item.id] = result['name'] as String? ?? 'Item #$selectedId';
            });
          }
        } else if (value != null) {
          setState(() => _pendingMappings[item.id] = value);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final status = bill.status;
    final isVerified = status == 'VERIFIED';
    final isProcessing = status == 'PROCESSING';
    final hasUnresolved = bill.unresolvedCount > 0;
    final pendingCount =
        _pendingMappings.values.where((v) => v != null).length;

    return ExpansionTile(
      onExpansionChanged: (expanded) async {
        if (expanded) {
          _loadSuggestions();
        } else {
          final hasUnsaved =
              _pendingMappings.values.any((v) => v != null);
          if (hasUnsaved) {
            final discard = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Unsaved Mappings'),
                content: const Text(
                  'You have unsaved mappings. Discard them?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            );
            if (discard != true) return;
          }
          _clearState();
        }
      },
      title: Row(
        children: [
          Expanded(
            child: Text(
              bill.martName ?? 'Unknown Mart',
              style: AgroTypography.cardTitle,
            ),
          ),
          if (hasUnresolved && !isVerified)
            Container(
              margin: const EdgeInsets.only(right: AgroSpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: AgroSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AgroColors.warning.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${bill.unresolvedCount} unresolved',
                style: AgroTypography.caption.copyWith(
                  color: AgroColors.warning.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          AgroStatusBadge.fromBillStatus(status),
        ],
      ),
      subtitle: Text(
        '${DateFormat('MMM dd, yyyy').format(DateTime.parse(bill.invoiceDate!))}   \u20b9 ${bill.totalAmount.toStringAsFixed(2)}',
        style: AgroTypography.caption,
      ),
      trailing: Wrap(
        spacing: AgroSpacing.xs,
        children: [
          if (!isProcessing)
            Tooltip(
              message: isVerified
                  ? 'Unlock Bill'
                  : hasUnresolved
                      ? 'Resolve all items before verifying'
                      : 'Verify Bill',
              child: IconButton(
                icon: Icon(
                  isVerified ? Icons.lock : Icons.lock_open,
                  color: isVerified
                      ? AgroColors.success.text
                      : hasUnresolved
                          ? AgroColors.divider
                          : AgroColors.textDisabled,
                ),
                onPressed: () async {
                  if (isVerified) {
                    try {
                      await widget.onUnverify(bill.id);
                    } catch (e) {
                      if (!context.mounted) return;
                      AgroSnackBar.error(context, e.toString());
                    }
                  } else if (hasUnresolved) {
                    _showVerifyBlockedDialog(context);
                  } else {
                    try {
                      await widget.onVerify(bill.id);
                    } catch (e) {
                      if (!context.mounted) return;
                      AgroSnackBar.error(context, e.toString());
                    }
                  }
                },
              ),
            ),
          Tooltip(
            message: 'Delete Bill',
            child: IconButton(
              icon: Icon(
                Icons.delete,
                color:
                    isVerified ? AgroColors.divider : AgroColors.critical.text,
              ),
              onPressed:
                  isVerified
                      ? () {
                        AgroSnackBar.error(
                          context,
                          'Cannot delete a verified bill. Unlock it first.',
                        );
                      }
                      : () => widget.onDelete(bill.id),
            ),
          ),
        ],
      ),
      children: [
        ListTile(
          title: Text(
            (bill.filePath ?? '').split('/').last,
            style: AgroTypography.body,
          ),
          trailing: TextButton(
            onPressed: () {
              context.push(
                '/pdf-viewer',
                extra: bill.id,
              );
            },
            child: const Text('View'),
          ),
        ),
        if (pendingCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AgroSpacing.md,
              vertical: AgroSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$pendingCount mapping${pendingCount == 1 ? '' : 's'} ready',
                    style: AgroTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAllMappings,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save, size: 16),
                  label: Text('Save $pendingCount mapping${pendingCount == 1 ? '' : 's'}'),
                ),
              ],
            ),
          ),
        FutureBuilder<List<MartBillItem>>(
          future: widget.onFetchItems(bill.id),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const LinearProgressIndicator();
            }
            final items = snap.data!;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('UOM')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Map To')),
                  DataColumn(label: Text('Actions')),
                ],
                rows:
                    items.map((it) {
                      final hasPending = _pendingMappings[it.id] != null;
                      final isAuto = _autoFilledIds.contains(it.id) && hasPending;
                      final isManual = !isAuto && hasPending;

                      return DataRow(
                        color: isAuto
                            ? WidgetStateProperty.all(
                                Colors.green.withValues(alpha: 0.06),
                              )
                            : isManual
                                ? WidgetStateProperty.all(
                                    Colors.blue.withValues(alpha: 0.05),
                                  )
                                : it.isUnresolved
                                    ? WidgetStateProperty.all(
                                        Colors.orange.withValues(alpha: 0.05),
                                      )
                                    : null,
                        cells: [
                          DataCell(Text(it.itemName)),
                          DataCell(Text(it.quantity.toString())),
                          DataCell(Text(it.uom)),
                          DataCell(
                            Text(it.price.toStringAsFixed(2)),
                          ),
                          DataCell(
                            Text(it.total.toStringAsFixed(2)),
                          ),
                          DataCell(
                            Icon(
                              it.isUnresolved
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              size: 18,
                              color: it.isUnresolved
                                  ? AgroColors.warning.text
                                  : AgroColors.success.text,
                            ),
                          ),
                          DataCell(
                            it.isUnresolved && !isVerified
                                ? _suggestionsLoaded
                                    ? SizedBox(
                                        width: 180,
                                        child: _buildMappingDropdown(it),
                                      )
                                    : const SizedBox(
                                        width: 180,
                                        child: Center(
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      )
                                : Text(
                                    'Mapped',
                                    style: AgroTypography.caption.copyWith(
                                      color: AgroColors.success.text,
                                    ),
                                  ),
                          ),
                          DataCell(
                            isVerified
                                ? const Icon(
                                  Icons.lock,
                                  size: 16,
                                  color: AgroColors.textDisabled,
                                )
                                : PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18),
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await widget.onEditItem(it);
                                    } else if (value == 'delete') {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (_) => AlertDialog(
                                              title: const Text('Delete Item'),
                                              content: const Text(
                                                'Are you sure you want to delete this item?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('No'),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text('Yes'),
                                                ),
                                              ],
                                            ),
                                      );
                                      if (confirmed == true) {
                                        await widget.onDeleteItem(it.id);
                                      }
                                    } else if (value == 'map') {
                                      await InlineItemMappingSheet.show(
                                        context,
                                        billItem: it,
                                        billId: bill.id,
                                      );
                                    }
                                  },
                                  itemBuilder:
                                      (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        if (it.isUnresolved)
                                          const PopupMenuItem(
                                            value: 'map',
                                            child: Text('Map'),
                                          ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}
