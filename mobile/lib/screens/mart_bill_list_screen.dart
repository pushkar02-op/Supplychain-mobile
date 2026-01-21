import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/mart_bill_service.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_status_badge.dart';

class MartBillListScreen extends StatefulWidget {
  const MartBillListScreen({Key? key}) : super(key: key);
  @override
  State<MartBillListScreen> createState() => _MartBillListScreenState();
}

class _MartBillListScreenState extends State<MartBillListScreen> {
  DateTime? _filterDate;
  String? _filterMart;
  String _search = '';
  List<Map<String, dynamic>> _martBills = [];
  List<String> _marts = [];
  bool _loading = true, _uploading = false;
  String? _error;
  List<String> _pickedPaths = [];
  List<Map<String, dynamic>> _uploadResults = [];
  bool _showUploadSection = false;
  int _skip = 0;
  final int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _totalBills = 0;

  @override
  void initState() {
    super.initState();
    _loadMarts();
    _fetchMartBills();
  }

  Future<void> _loadMarts() async {
    try {
      final list = await MartBillService.fetchMartNames();
      setState(() => _marts = list);
    } catch (_) {}
  }

  // PRESERVED EXACTLY: Pagination logic
  Future<void> _fetchMartBills({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() {
        _isLoadingMore = true;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _skip = 0; // Reset
        _hasMore = true;
        _martBills.clear();
      });
    }
    try {
      final result = await MartBillService.fetchMartBills(
        date: _filterDate,
        martName: _filterMart,
        search: _search.isNotEmpty ? _search : null,
        skip:
            loadMore
                ? _skip + _limit
                : 0, // Calculate next skip if loading more
        limit: _limit,
      );

      final list = List<Map<String, dynamic>>.from(result['items']);
      final fetchedSkip = result['skip'] as int;
      final fetchedTotal = result['total'] as int;
      final fetchedHasMore = result['has_more'] as bool;

      setState(() {
        if (loadMore) {
          _martBills.addAll(list);
          _skip = fetchedSkip; // Update current skip
        } else {
          _martBills = list;
          _skip = 0;
        }
        _totalBills = fetchedTotal;
        _hasMore = fetchedHasMore;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (loadMore) {
        setState(() => _isLoadingMore = false);
      } else {
        setState(() => _loading = false);
      }
    }
  }

  // PRESERVED EXACTLY: File picking
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      final pdfFiles =
          result.files
              .where(
                (file) =>
                    file.path != null &&
                    file.path!.toLowerCase().endsWith('.pdf'),
              )
              .toList();

      setState(() {
        _pickedPaths =
            pdfFiles.map((file) => file.path!).toList().cast<String>();
        _showUploadSection = true;
        _uploadResults.clear();
      });
    }
  }

  // PRESERVED EXACTLY: Upload logic
  Future<void> _uploadFiles() async {
    if (_pickedPaths.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadResults.clear();
      _error = null;
    });

    try {
      final responses = await MartBillService.uploadMartBills(_pickedPaths);

      for (final resp in responses) {
        if (resp['unmapped_items'] != null &&
            resp['unmapped_items'].isNotEmpty) {
          final billId =
              resp['invoice_id']; // field name might still be invoice_id in response for now
          final unmappedItems = List<Map<String, dynamic>>.from(
            resp['unmapped_items'],
          );
          // Navigation to mapping screen currently commented out in original code
        }
      }

      setState(() {
        _uploadResults = responses;
        _pickedPaths.clear();
        _showUploadSection = false;
      });

      await _fetchMartBills();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
      _fetchMartBills();
    }
  }

  // PRESERVED EXACTLY: Delete confirmation dialog
  Future<void> _confirmDelete(int id) async {
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
      await MartBillService.deleteMartBill(id);
      _fetchMartBills();
    }
  }

  // PRESERVED EXACTLY: Edit item dialog
  Future<void> _showEditItemDialog(Map<String, dynamic> item) async {
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
      final total = qty * price;
      totalController.text = total.toStringAsFixed(2);
    }

    calculateTotal();

    qtyController.addListener(calculateTotal);
    priceController.addListener(calculateTotal);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
                final updatedQty = double.tryParse(qtyController.text);
                final updatedPrice = double.tryParse(priceController.text);
                final updatedTotal = double.tryParse(totalController.text);

                if (updatedQty == null ||
                    updatedPrice == null ||
                    updatedTotal == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid input')),
                  );
                  return;
                }

                await MartBillService.updateMartBillItem(item['id'], {
                  'quantity': updatedQty,
                  'price': updatedPrice,
                  'total': updatedTotal,
                });
                Navigator.pop(context);
                await _fetchMartBills();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: _pickFiles,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(AgroSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter row
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _filterDate == null
                        ? 'All Dates'
                        : DateFormat('yyyy-MM-dd').format(_filterDate!),
                  ),
                ),
                const SizedBox(width: AgroSpacing.md),
                Expanded(
                  child: DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _filterMart,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AgroSpacing.md,
                        vertical: AgroSpacing.sm + 2, // 10px
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
                      ..._marts.map(
                        (m) => DropdownMenuItem(value: m, child: Text(m)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _filterMart = v;
                        _fetchMartBills();
                      });
                    },
                  ),
                ),
                const SizedBox(width: AgroSpacing.md),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Search…'),
                    onSubmitted: (v) {
                      _search = v;
                      _fetchMartBills();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: AgroSpacing.md),

            if (_error != null)
              Center(
                child: Text(
                  _error!,
                  style: TextStyle(color: AgroColors.critical.text),
                ),
              ),

            const SizedBox(height: AgroSpacing.md),

            // 1) UPLOAD FORM CARD
            if (_showUploadSection) _buildUploadFormCard(),

            // 2) UPLOAD RESULTS CARD
            if (_uploadResults.isNotEmpty) _buildUploadResultsCard(),

            // List
            Expanded(child: _buildBillList()),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadFormCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: AgroSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: AgroShapes.containerRadius),
      child: Padding(
        padding: EdgeInsets.all(AgroSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Selected Files', style: AgroTypography.cardTitle),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel Upload',
                  onPressed: () {
                    setState(() {
                      _pickedPaths.clear();
                      _showUploadSection = false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: AgroSpacing.sm),
            ..._pickedPaths.map(
              (p) => Text('• ${p.split('/').last}', style: AgroTypography.body),
            ),
            const SizedBox(height: AgroSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon:
                    _uploading
                        ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AgroColors.surface,
                          ),
                        )
                        : const Icon(Icons.cloud_upload),
                label: const Text('Upload'),
                onPressed: _uploading ? null : _uploadFiles,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadResultsCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: AgroSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: AgroShapes.containerRadius),
      child: Padding(
        padding: EdgeInsets.all(AgroSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Upload Results', style: AgroTypography.cardTitle),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Dismiss Results',
                  onPressed: () {
                    setState(() {
                      _uploadResults.clear();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: AgroSpacing.sm),
            for (final result in _uploadResults)
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
                onPressed: () {
                  setState(() {
                    _uploadResults.clear();
                    _pickedPaths.clear();
                    _showUploadSection = true;
                  });
                  _pickFiles();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_martBills.isEmpty) {
      return AgroEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No mart bills found',
        actionLabel: 'Upload your first bill',
        onAction: _pickFiles,
      );
    }

    // PRESERVED EXACTLY: ListView with pagination
    return ListView.builder(
      padding: EdgeInsets.only(top: AgroSpacing.md, bottom: AgroSpacing.xl),
      itemCount: _martBills.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _martBills.length) {
          return Padding(
            padding: EdgeInsets.all(AgroSpacing.lg),
            child: Center(
              child:
                  _isLoadingMore
                      ? const CircularProgressIndicator()
                      : _error != null
                      ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Failed to load more items',
                            style: TextStyle(color: AgroColors.critical.text),
                          ),
                          const SizedBox(height: AgroSpacing.sm),
                          ElevatedButton.icon(
                            onPressed: () => _fetchMartBills(loadMore: true),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      )
                      : ElevatedButton.icon(
                        onPressed: () => _fetchMartBills(loadMore: true),
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('Load More'),
                      ),
            ),
          );
        }
        final bill = _martBills[i];
        return _BillCard(
          bill: bill,
          onRefresh: _fetchMartBills,
          onDelete: _confirmDelete,
          onEditItem: _showEditItemDialog,
        );
      },
    );
  }
}

/// Bill card with expansion tile displaying bill details and items.
/// Preserves all verify/unverify and delete callbacks exactly.
class _BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int) onDelete;
  final Future<void> Function(Map<String, dynamic>) onEditItem;

  const _BillCard({
    required this.bill,
    required this.onRefresh,
    required this.onDelete,
    required this.onEditItem,
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
        '${DateFormat('MMM dd, yyyy').format(DateTime.parse(bill['invoice_date']))}   ₹ ${bill['total_amount'].toStringAsFixed(2)}',
        style: AgroTypography.caption,
      ),
      trailing: Wrap(
        spacing: AgroSpacing.xs,
        children: [
          // PRESERVED EXACTLY: Verify/Unverify button
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
                      await MartBillService.unverifyMartBill(bill['id']);
                    } else {
                      await MartBillService.verifyMartBill(bill['id']);
                    }
                    onRefresh();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
              ),
            ),
          // PRESERVED EXACTLY: Delete button
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cannot delete a verified bill. Unlock it first.',
                            ),
                          ),
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
          future: MartBillService.fetchMartBillItems(bill['id']),
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
                            // PRESERVED EXACTLY: Item actions with edit/delete
                            isVerified
                                ? Icon(
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
                                      // PRESERVED EXACTLY: Item delete confirmation
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
                                        await MartBillService.deleteMartBillItem(
                                          it['id'],
                                        );
                                        onRefresh();
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
