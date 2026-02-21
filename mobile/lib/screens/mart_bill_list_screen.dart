import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/mart_bill_provider.dart';
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
    Map<String, dynamic> item,
  ) async {
    final qtyController = TextEditingController(
      text: item['quantity'].toString(),
    );
    final priceController = TextEditingController(
      text: item['price'].toString(),
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
                    item['id'],
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
      martBillMartListProvider.select(
        (async) => async.valueOrNull ?? const <String>[],
      ),
    );

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
                        value: state.selectedMart,
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
                                ref.read(martBillProvider.notifier).setMart(v),
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
                Expanded(child: _buildBillList(context, ref, state)),
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
      return AgroEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No mart bills found',
        actionLabel: 'Upload your first bill',
        onAction: () => _pickFiles(ref),
      );
    }

    return ListView.builder(
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
          onDelete: (id) => _confirmDelete(context, ref, id),
          onEditItem: (item) => _showEditItemDialog(context, ref, item),
          onVerify: (id) => ref.read(martBillProvider.notifier).verifyBill(id),
          onUnverify:
              (id) => ref.read(martBillProvider.notifier).unverifyBill(id),
          onFetchItems:
              (id) => ref.read(martBillProvider.notifier).fetchBillItems(id),
          onDeleteItem:
              (id) => ref.read(martBillProvider.notifier).deleteBillItem(id),
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
                subtitle:
                    result['success'] == true
                        ? null
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

class _BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;
  final Future<void> Function(int) onDelete;
  final Future<void> Function(Map<String, dynamic>) onEditItem;
  final Future<void> Function(int) onVerify;
  final Future<void> Function(int) onUnverify;
  final Future<List<Map<String, dynamic>>> Function(int) onFetchItems;
  final Future<void> Function(int) onDeleteItem;

  const _BillCard({
    required this.bill,
    required this.onDelete,
    required this.onEditItem,
    required this.onVerify,
    required this.onUnverify,
    required this.onFetchItems,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    final status = bill['status'] as String? ?? 'NEEDS_REVIEW';
    final isVerified = status == 'VERIFIED';
    final isProcessing = status == 'PROCESSING';

    return ExpansionTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              bill['mart_name'] ?? 'Unknown Mart',
              style: AgroTypography.cardTitle,
            ),
          ),
          AgroStatusBadge.fromBillStatus(status),
        ],
      ),
      subtitle: Text(
        '${DateFormat('MMM dd, yyyy').format(DateTime.parse(bill['invoice_date']))}   \u20b9 ${bill['total_amount'].toStringAsFixed(2)}',
        style: AgroTypography.caption,
      ),
      trailing: Wrap(
        spacing: AgroSpacing.xs,
        children: [
          if (!isProcessing)
            Tooltip(
              message: isVerified ? 'Unlock Bill' : 'Verify Bill',
              child: IconButton(
                icon: Icon(
                  isVerified ? Icons.lock : Icons.lock_open,
                  color:
                      isVerified
                          ? AgroColors.success.text
                          : AgroColors.textDisabled,
                ),
                onPressed: () async {
                  try {
                    if (isVerified) {
                      await onUnverify(bill['id']);
                    } else {
                      await onVerify(bill['id']);
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    AgroSnackBar.error(context, e.toString());
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
                      : () => onDelete(bill['id']),
            ),
          ),
        ],
      ),
      children: [
        ListTile(
          title: Text(
            bill['file_path'].toString().split('/').last,
            style: AgroTypography.body,
          ),
          trailing: TextButton(
            onPressed: () {
              context.push(
                '/pdf-viewer',
                extra: int.parse(bill['id'].toString()),
              );
            },
            child: const Text('View'),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: onFetchItems(bill['id']),
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
                  DataColumn(label: Text('Actions')),
                ],
                rows:
                    items.map((it) {
                      return DataRow(
                        cells: [
                          DataCell(Text(it['item_name'] ?? '')),
                          DataCell(Text(it['quantity'].toString())),
                          DataCell(Text(it['uom'] ?? '')),
                          DataCell(
                            Text((it['price'] as num).toStringAsFixed(2)),
                          ),
                          DataCell(
                            Text((it['total'] as num).toStringAsFixed(2)),
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
                                      await onEditItem(it);
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
                                        await onDeleteItem(it['id']);
                                      }
                                    }
                                  },
                                  itemBuilder:
                                      (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
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
